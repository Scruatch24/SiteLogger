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
      this.buttonTarget.innerText = "Stop & Process"
      this.buttonTarget.classList.add("bg-red-600", "ring-4", "ring-red-100")
      this.buttonTarget.classList.remove("bg-orange-600")
    } catch (err) {
      console.error("Microphone error:", err)
      alert("Microphone access denied. Please enable it in settings.")
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop()
      this.recording = false

      window.trackEvent('recording_completed');

      // 3. Disable button during AI processing to prevent double-uploads
      this.buttonTarget.innerText = "Analyzing Audio..."
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

      this.buttonTarget.innerText = "Record Another"

    } catch (error) {
      console.error("Processing error:", error)
      alert("AI failed to process audio: " + error.message)
      this.buttonTarget.innerText = "Try Again"
    } finally {
      // 5. Re-enable button
      this.buttonTarget.disabled = false
      this.buttonTarget.classList.remove("opacity-50", "cursor-not-allowed")
      this.buttonTarget.classList.add("bg-orange-600")

      if (this.hasTranscriptContainerTarget) {
        this.transcriptContainerTarget.classList.remove("analyzing")
      }
    }

    if (this.hasTasksTarget) {
      this.tasksTarget.innerHTML = (data.tasks || []).map(t => `
        <li class="flex items-center gap-3 mb-2 animate-in slide-in-from-left-2 duration-300">
          <div class="w-1.5 h-1.5 bg-black rounded-full flex-shrink-0"></div>
          <input type="text" value="${t}" class="flex-1 bg-white border-b-2 border-gray-100 text-sm font-bold text-black focus:border-orange-500 focus:ring-0 py-2 px-1">
          
          <div class="flex items-center border-2 border-black rounded-xl overflow-hidden h-10 bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] flex-shrink-0">
            <div class="bg-orange-50 px-2 h-full flex items-center justify-center border-r-2 border-black min-w-[35px]">
              <span class="text-[10px] font-black text-orange-600">${symbol}</span>
            </div>
            <input type="number" step="0.01" class="w-20 h-full bg-white text-xs font-black text-black focus:ring-0 border-none py-0 px-2 text-right" placeholder="0.00">
          </div>
        </li>
      `).join('');
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