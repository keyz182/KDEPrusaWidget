import QtQuick

// Polls a printer's PrusaLink API and exposes its state as a backend-neutral
// set of properties. The UI reads only the "outputs" below, never raw
// PrusaLink JSON, so another backend (e.g. Prusa Connect cloud) can replace
// this component by providing the same properties and functions.
//
// Contract:
//   connState      "unknown" | "unreachable" | "authFailed" | "ok"
//   printerState   upstream state name, e.g. "PRINTING", "ATTENTION"
//   severity       "normal" | "active" | "attention" | "error"
//   statusMessage  human-readable detail for the current state, may be ""
//   job            null, or { id, filename, progress (0..1),
//                  timeRemaining (s, -1 if unknown), timePrinting (s) }
//   temps          null, or { nozzle, nozzleTarget, bed, bedTarget }
//   thumbnailUrl   loadable by <Image>, "" when none
//   lastSuccess    Date of the last good poll, or null
//   controlsBusy   true from a control click until the next poll completes
//   lastActionError
//   canPause / canResume / canStop
//   pause() / resume() / stop()
//
// Auth: Qt's network stack answers PrusaLink's HTTP Digest challenge itself
// when given credentials — via the 5-arg XMLHttpRequest.open() for XHR, and
// via URL userinfo for <Image>. No digest code is needed here.
QtObject {
    id: client

    // --- inputs ---
    property string baseUrl: ""
    property string username: ""
    property string password: ""
    property string apiKey: ""
    property int activeInterval: 5
    property int idleInterval: 15

    // --- outputs ---
    property string connState: "unknown"
    property string printerState: ""
    property string severity: "normal"
    property string statusMessage: ""
    property var job: null
    property var temps: null
    property string thumbnailUrl: ""
    property var lastSuccess: null
    property bool controlsBusy: false
    property string lastActionError: ""

    readonly property bool canPause: connState === "ok" && job !== null && printerState === "PRINTING"
    readonly property bool canResume: connState === "ok" && job !== null && printerState === "PAUSED"
    readonly property bool canStop: connState === "ok" && job !== null
        && (printerState === "PRINTING" || printerState === "PAUSED" || printerState === "ATTENTION")

    // --- internals ---
    property int _backoffStep: 0
    readonly property var _backoffSteps: [5, 10, 20, 60]
    property var _activeXhr: null
    property int _jobDetailsId: -1
    property var _jobDetails: null
    property var _lastStatusJob: null

    readonly property string _normalizedBase: baseUrl.replace(/\/+$/, "")
    readonly property bool _useApiKey: apiKey.length > 0

    // Maps a PrusaLink printer state to a UI severity:
    //   "error"     — the job or printer has failed; NeedsAttention + error icon
    //   "attention" — printer is waiting for a human; NeedsAttention + warning icon
    //   "active"    — work in progress; panel shows progress
    //   "normal"    — nothing to report
    // `printerOk` is status_printer.ok from PrusaLink (undefined when absent).
    function _severityFor(state, printerOk) {
        switch (state) {
        case "ERROR":
            return "error"
        case "ATTENTION":
        case "FINISHED": // bed needs clearing before the next print
            return "attention"
        }
        // The printer can report a problem while its state still looks fine.
        if (printerOk === false) {
            return "attention"
        }
        switch (state) {
        case "PRINTING":
        case "PAUSED":
        case "BUSY":
            return "active"
        default: // IDLE, READY, STOPPED (usually user-initiated), unknown
            return "normal"
        }
    }

    function _isActive() {
        return severity === "active" || job !== null
    }

    function _nextInterval() {
        if (connState !== "ok") {
            return _backoffSteps[Math.min(_backoffStep, _backoffSteps.length - 1)]
        }
        return _isActive() ? activeInterval : idleInterval
    }

    function _open(xhr, method, path) {
        const url = _normalizedBase + path
        if (_useApiKey) {
            xhr.open(method, url)
            xhr.setRequestHeader("X-Api-Key", apiKey)
        } else if (username.length > 0) {
            xhr.open(method, url, true, username, password)
        } else {
            xhr.open(method, url)
        }
        xhr.timeout = 5000
    }

    // <Image> can't set headers, so it only gets credentials via URL userinfo.
    // Returns "" in API-key mode, where the thumbnail can't be authenticated.
    function _imageUrl(path) {
        if (_useApiKey) {
            return ""
        }
        const m = _normalizedBase.match(/^(https?:\/\/)(.*)$/)
        if (!m || username.length === 0) {
            return _normalizedBase + path
        }
        return m[1] + encodeURIComponent(username) + ":" + encodeURIComponent(password) + "@" + m[2] + path
    }

    function _abortActive() {
        if (_activeXhr) {
            _activeXhr.onreadystatechange = null
            _activeXhr.ontimeout = null
            try {
                _activeXhr.abort()
            } catch (e) {
                // already finished/aborted
            }
            _activeXhr = null
        }
    }

    function _clearData() {
        job = null
        temps = null
        printerState = ""
        severity = "normal"
        thumbnailUrl = ""
        _jobDetailsId = -1
        _jobDetails = null
        _lastStatusJob = null
    }

    function _setFailed(state, message) {
        _clearData()
        connState = state
        statusMessage = message
        _backoffStep = Math.min(_backoffStep + 1, _backoffSteps.length - 1)
        pollTimer.interval = _nextInterval() * 1000
        controlsBusy = false
    }

    function _failFromStatus(status) {
        if (status === 0) {
            _setFailed("unreachable", i18n("Host unreachable"))
        } else if (status === 401 || status === 403) {
            _setFailed("authFailed", _useApiKey
                ? i18n("The printer rejected the API key")
                : i18n("The printer rejected the username or password"))
        } else {
            _setFailed("unreachable", i18n("PrusaLink returned HTTP %1", status))
        }
    }

    function _buildJob(statusJob) {
        if (!statusJob || statusJob.id === undefined) {
            return null
        }
        const details = (_jobDetails && _jobDetailsId === statusJob.id) ? _jobDetails : null
        const file = details && details.file ? details.file : null
        return {
            id: statusJob.id,
            filename: file ? (file.display_name || file.name || "") : "",
            progress: (statusJob.progress || 0) / 100,
            timeRemaining: statusJob.time_remaining !== undefined ? statusJob.time_remaining : -1,
            timePrinting: statusJob.time_printing || 0,
        }
    }

    function _setOk(data) {
        const p = data.printer || {}
        const printerOk = p.status_printer ? p.status_printer.ok : undefined

        // Data must land before connState flips to "ok" — dependent bindings
        // re-evaluate on each write and would otherwise see "ok" with stale data.
        printerState = p.state || ""
        severity = _severityFor(printerState, printerOk)
        statusMessage = (p.status_printer && p.status_printer.message && printerOk === false)
            ? p.status_printer.message : ""
        temps = {
            nozzle: p.temp_nozzle,
            nozzleTarget: p.target_nozzle,
            bed: p.temp_bed,
            bedTarget: p.target_bed,
        }
        _lastStatusJob = data.job || null
        job = _buildJob(_lastStatusJob)
        connState = "ok"
        lastSuccess = new Date()
        _backoffStep = 0
        pollTimer.interval = _nextInterval() * 1000
        controlsBusy = false

        if (!job) {
            thumbnailUrl = ""
            _jobDetailsId = -1
            _jobDetails = null
        } else if (job.id !== _jobDetailsId) {
            _jobDetailsId = job.id
            _jobDetails = null
            thumbnailUrl = ""
            _fetchJobDetails(job.id)
        }
    }

    function poll() {
        if (_normalizedBase.length === 0) {
            _clearData()
            connState = "unknown"
            return
        }

        _abortActive()

        const xhr = new XMLHttpRequest()
        _activeXhr = xhr
        _open(xhr, "GET", "/api/v1/status")
        xhr.ontimeout = function () {
            _setFailed("unreachable", i18n("Connection timed out"))
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            _activeXhr = null
            if (xhr.status !== 200) {
                _failFromStatus(xhr.status)
                return
            }
            let data
            try {
                data = JSON.parse(xhr.responseText)
            } catch (e) {
                _setFailed("unreachable", i18n("Unexpected response from PrusaLink"))
                return
            }
            _setOk(data)
        }
        xhr.send()
    }

    // /api/v1/status carries progress but not the file; /api/v1/job has the
    // file name and thumbnail ref. Fetched once per job id.
    function _fetchJobDetails(jobId) {
        const xhr = new XMLHttpRequest()
        _open(xhr, "GET", "/api/v1/job")
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) {
                return
            }
            let details
            try {
                details = JSON.parse(xhr.responseText)
            } catch (e) {
                return
            }
            if (details.id !== jobId || _jobDetailsId !== jobId) {
                return
            }
            _jobDetails = details
            if (job && job.id === jobId) {
                job = _buildJob(_lastStatusJob)
            }
            const refs = details.file && details.file.refs
            thumbnailUrl = (refs && refs.thumbnail) ? _imageUrl(refs.thumbnail) : ""
        }
        xhr.send()
    }

    // --- print controls ---

    function _control(method, path) {
        controlsBusy = true
        lastActionError = ""
        const xhr = new XMLHttpRequest()
        _open(xhr, method, path)
        xhr.ontimeout = function () {
            lastActionError = i18n("Request timed out")
            controlsBusy = false
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            if (xhr.status === 204 || xhr.status === 200) {
                // Re-poll now so the UI reflects the new state and the
                // controls unlock without waiting for the next tick.
                client.poll()
                return
            }
            if (xhr.status === 0) {
                lastActionError = i18n("Host unreachable")
            } else if (xhr.status === 409) {
                lastActionError = i18n("The printer can't do that in its current state")
            } else {
                lastActionError = i18n("Printer rejected the request (%1)", xhr.status)
            }
            controlsBusy = false
        }
        xhr.send()
    }

    function pause() {
        if (canPause) {
            _control("PUT", "/api/v1/job/" + job.id + "/pause")
        }
    }

    function resume() {
        if (canResume) {
            _control("PUT", "/api/v1/job/" + job.id + "/resume")
        }
    }

    function stop() {
        if (canStop) {
            _control("DELETE", "/api/v1/job/" + job.id)
        }
    }

    property Timer pollTimer: Timer {
        interval: 5000
        repeat: true
        running: client._normalizedBase.length > 0
        onTriggered: client.poll()
        onRunningChanged: if (running) client.poll()
    }
}
