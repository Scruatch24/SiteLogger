import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Added currencySymbol target for the Settings page fix we discussed
  static targets = ["button", "output", "date", "client", "tasks", "materials", "time", "currencySymbol", "transcriptContainer"]

  static values = {
    currencySymbols: Object
  }

  connect() {
    this.recording = false
    this.mediaRecorder = null
    this.chunks = []
  }

  async toggle() {
    if (this.recording) {
      this.stopRecording()
    } else {
      this.startRecording()
    }
  }

  async startRecording() {
    try {
      // 1. Reset UI from previous recordings
      if (this.hasOutputTarget) this.outputTarget.classList.add("hidden")

      // Fix: Clear previous transcript to ensure only new audio is processed
      const transcriptInput = document.getElementById('mainTranscript');
      if (transcriptInput) transcriptInput.value = "";

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream)
      this.chunks = []

      this.mediaRecorder.ondataavailable = (e) => this.chunks.push(e.data)

      this.mediaRecorder.onstop = async () => {
        const blob = new Blob(this.chunks, { type: 'audio/webm' })
        this.processAudio(blob)
      }

      this.mediaRecorder.start()
      this.recording = true

      window.trackEvent('recording_started');

      // 2. Professional Recording State
      this.buttonTarget.innerText = window.APP_LANGUAGES ? window.APP_LANGUAGES.stop_process : "Stop & Process"
      this.buttonTarget.classList.add("bg-red-600", "ring-4", "ring-red-100")
      this.buttonTarget.classList.remove("bg-orange-600")
    } catch (err) {
      console.error("Microphone error:", err)
      alert(window.APP_LANGUAGES ? (window.APP_LANGUAGES.microphone_access_denied || "Microphone access denied.") : "Microphone access denied. Please enable it in settings.")
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop()
      this.recording = false

      window.trackEvent('recording_completed');

      // 3. Disable button during AI processing to prevent double-uploads
      this.buttonTarget.innerText = window.APP_LANGUAGES ? window.APP_LANGUAGES.analyzing_audio : "Analyzing Audio..."
      this.buttonTarget.disabled = true
      this.buttonTarget.classList.remove("bg-red-600", "ring-4", "ring-red-100")
      this.buttonTarget.classList.add("opacity-50", "cursor-not-allowed")

      if (this.hasTranscriptContainerTarget) {
        this.transcriptContainerTarget.classList.add("analyzing")
      }

      this.mediaRecorder.stream.getTracks().forEach(track => track.stop())
    }
  }

  async processAudio(blob) {
    const formData = new FormData()
    formData.append('audio', blob, 'recording.webm')
    const token = document.querySelector('meta[name="csrf-token"]').content

    try {
      const response = await fetch('/process_audio', {
        method: 'POST',
        headers: { 'X-CSRF-Token': token },
        body: formData
      })

      const data = await response.json()

      if (data.error) throw new Error(data.error)

      window.trackEvent('invoice_generated');

      // 4. Populate and Show Results
      if (this.hasOutputTarget) {
        this.dateTarget.innerText = data.date || "-"
        this.clientTarget.innerText = data.client || "-"
        this.timeTarget.innerText = data.time || "-"
        this.tasksTarget.innerHTML = (data.tasks || []).map(t => `<li>• ${t}</li>`).join('')
        this.materialsTarget.innerHTML = (data.materials || []).map(m => `<li>• ${m}</li>`).join('')

        this.outputTarget.classList.remove("hidden")
        // Smooth scroll to results
        this.outputTarget.scrollIntoView({ behavior: 'smooth' })
      }

      this.buttonTarget.innerText = window.APP_LANGUAGES ? window.APP_LANGUAGES.record_another : "Record Another"

    } catch (error) {
      console.error("Processing error:", error)
      alert((window.APP_LANGUAGES ? (window.APP_LANGUAGES.processing_error || "AI failed to process audio: ") : "AI failed to process audio: ") + error.message)
      this.buttonTarget.innerText = window.APP_LANGUAGES ? window.APP_LANGUAGES.try_again : "Try Again"
    } finally {
      // 5. Re-enable button
      this.buttonTarget.disabled = false
      this.buttonTarget.classList.remove("opacity-50", "cursor-not-allowed")
      this.buttonTarget.classList.add("bg-orange-600")

      if (this.hasTranscriptContainerTarget) {
        this.transcriptContainerTarget.classList.remove("analyzing")
      }
    }
  }

  // logic for the Settings Page "Instant Symbol" update
  updateCurrencySymbol(event) {
    // 2. Access the value passed from Rails
    const symbols = this.currencySymbolsValue;
    const selectedCode = event.target.value;
    const symbol = symbols[selectedCode] || selectedCode;

    if (this.hasCurrencySymbolTarget) {
      this.currencySymbolTarget.textContent = `(${symbol})`;
    }
  }
}