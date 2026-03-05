// AudioWorklet processor for ElevenLabs Scribe Realtime STT
// Downsamples mic audio to 16kHz PCM Int16 and sends via postMessage
class AudioProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this._targetRate = 16000;
    this._buffer = [];
    this._chunkSize = 1600; // 100ms at 16kHz
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || !input[0] || input[0].length === 0) return true;

    const channelData = input[0];
    const ratio = sampleRate / this._targetRate;

    for (let i = 0; i < channelData.length; i += ratio) {
      const idx = Math.round(i);
      if (idx < channelData.length) {
        const s = Math.max(-1, Math.min(1, channelData[idx]));
        this._buffer.push(s < 0 ? s * 0x8000 : s * 0x7FFF);
      }
    }

    while (this._buffer.length >= this._chunkSize) {
      const chunk = this._buffer.splice(0, this._chunkSize);
      const int16 = new Int16Array(chunk);
      this.port.postMessage(int16.buffer, [int16.buffer]);
    }

    return true;
  }
}

registerProcessor('audio-processor', AudioProcessor);
