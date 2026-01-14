import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "output", "date", "client", "tasks", "materials", "time"]

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
      this.buttonTarget.innerText = "Stop & Process"
      this.buttonTarget.classList.add("animate-pulse", "bg-red-700")
    } catch (err) {
      console.error("Microphone error:", err)
      alert("Could not access microphone. Please allow permissions.")
    }
  }

  stopRecording() {
    if (this.mediaRecorder) {
      this.mediaRecorder.stop()
      this.recording = false
      this.buttonTarget.innerText = "Processing..."
      this.buttonTarget.classList.remove("animate-pulse", "bg-red-700")
      
      // Stop all tracks to turn off the red dot on the tab
      this.mediaRecorder.stream.getTracks().forEach(track => track.stop())
    }
  }

  async processAudio(blob) {
    const formData = new FormData()
    formData.append('audio', blob, 'recording.webm')

    // Get the CSRF token to keep Rails happy
    const token = document.querySelector('meta[name="csrf-token"]').content

    try {
      const response = await fetch('/process_audio', {
        method: 'POST',
        headers: { 'X-CSRF-Token': token },
        body: formData
      })

      const data = await response.json()
      console.log("AI Response:", data) // <--- Look in your Browser Console (F12) for this!

      if (data.error) {
        alert("Error: " + data.error)
        this.buttonTarget.innerText = "Record Job"
        return
      }

      // Show the results div
      this.outputTarget.classList.remove("hidden")
      this.buttonTarget.innerText = "Record Another"

      // Fill the table (Safely)
      if (this.hasDateTarget) this.dateTarget.innerText = data.date || "-"
      if (this.hasClientTarget) this.clientTarget.innerText = data.client || "-"
      if (this.hasTimeTarget) this.timeTarget.innerText = data.time || "-"
      
      if (this.hasTasksTarget) {
        this.tasksTarget.innerHTML = (data.tasks || []).map(t => `<li>• ${t}</li>`).join('')
      }
      
      if (this.hasMaterialsTarget) {
        this.materialsTarget.innerHTML = (data.materials || []).map(m => `<li>• ${m}</li>`).join('')
      }

    } catch (error) {
      console.error("Upload error:", error)
      alert("Something went wrong. Check the console.")
      this.buttonTarget.innerText = "Retry"
    }
  }
}