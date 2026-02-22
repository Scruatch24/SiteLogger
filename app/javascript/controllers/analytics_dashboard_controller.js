import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart", "periodBtn", "metricTab"]
  static values = { dataUrl: String, currencySymbol: String }

  connect() {
    this.currentPeriod = "30d"
    this.currentMetric = "invoices"
    this.chartInstance = null
    this.waitForChartJs().then(() => this.loadChart())
  }

  waitForChartJs() {
    return new Promise((resolve) => {
      if (typeof Chart !== "undefined") return resolve()
      let attempts = 0
      const check = setInterval(() => {
        attempts++
        if (typeof Chart !== "undefined" || attempts > 50) {
          clearInterval(check)
          resolve()
        }
      }, 100)
    })
  }

  disconnect() {
    if (this.chartInstance) {
      this.chartInstance.destroy()
      this.chartInstance = null
    }
  }

  switchPeriod(event) {
    this.currentPeriod = event.currentTarget.dataset.period
    this.periodBtnTargets.forEach(btn => btn.classList.remove("active"))
    event.currentTarget.classList.add("active")
    this.loadChart()
  }

  switchMetric(event) {
    this.currentMetric = event.currentTarget.dataset.metric
    this.metricTabTargets.forEach(tab => tab.classList.remove("active"))
    event.currentTarget.classList.add("active")
    this.loadChart()
  }

  async loadChart() {
    const url = `${this.dataUrlValue}?period=${this.currentPeriod}&metric=${this.currentMetric}`

    try {
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) return

      const data = await response.json()
      this.renderChart(data.labels, data.values)
    } catch (e) {
      console.warn("Analytics chart load failed:", e)
    }
  }

  renderChart(labels, values) {
    if (typeof Chart === "undefined") {
      console.warn("Chart.js not loaded yet")
      return
    }

    if (this.chartInstance) {
      this.chartInstance.destroy()
    }

    const ctx = this.chartTarget.getContext("2d")
    const dataMax = values.length ? Math.max(...values) : 0
    const yMax = dataMax > 0 ? dataMax * 1.15 : 10

    const gradient = ctx.createLinearGradient(0, 0, 0, 280)
    gradient.addColorStop(0, "rgba(249, 115, 22, 0.35)")
    gradient.addColorStop(1, "rgba(249, 115, 22, 0.02)")

    const formatLabel = (label) => {
      if (this.currentPeriod === "12m") {
        const parts = label.split("-")
        const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return months[parseInt(parts[1], 10) - 1] || label
      }
      const parts = label.split("-")
      return `${parts[1]}/${parts[2]}`
    }

    const displayLabels = labels.map(formatLabel)

    this.chartInstance = new Chart(ctx, {
      type: "bar",
      data: {
        labels: displayLabels,
        datasets: [{
          data: values,
          borderColor: "#f97316",
          backgroundColor: gradient,
          borderWidth: 1.5,
          borderRadius: 4,
          borderSkipped: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: { top: 12 }
        },
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(0,0,0,0.85)",
            titleColor: "rgba(255,255,255,0.7)",
            bodyColor: "#f97316",
            bodyFont: { weight: "bold", size: 14 },
            borderColor: "rgba(249,115,22,0.3)",
            borderWidth: 1,
            cornerRadius: 12,
            padding: 12,
            displayColors: false,
            callbacks: {
              label: (ctx) => {
                const val = ctx.parsed.y
                const moneyMetrics = ["revenue", "collected", "outstanding"]
                const sym = this.currencySymbolValue || "$"
                if (moneyMetrics.includes(this.currentMetric)) {
                  return `${sym}${val.toLocaleString()}`
                }
                return val.toLocaleString()
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              color: "rgba(255,255,255,0.04)",
              drawBorder: false
            },
            ticks: {
              color: "rgba(255,255,255,0.35)",
              font: { size: 10, weight: "600" },
              maxRotation: 0,
              maxTicksLimit: this.currentPeriod === "7d" ? 7 : (this.currentPeriod === "12m" ? 12 : 10)
            }
          },
          y: {
            beginAtZero: true,
            suggestedMax: yMax,
            grid: {
              color: "rgba(255,255,255,0.04)",
              drawBorder: false
            },
            ticks: {
              color: "rgba(255,255,255,0.35)",
              font: { size: 10, weight: "600" },
              maxTicksLimit: 5,
              callback: (val) => {
                const moneyMetrics = ["revenue", "collected", "outstanding"]
                const sym = this.currencySymbolValue || "$"
                if (moneyMetrics.includes(this.currentMetric)) {
                  return sym + val.toLocaleString()
                }
                return val
              }
            }
          }
        }
      }
    })
  }
}
