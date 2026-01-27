// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "controllers"

const getSessionId = () => {
    let sid = sessionStorage.getItem('tracking_session_id');
    if (!sid) {
        sid = 'sess_' + Math.random().toString(36).substr(2, 9);
        sessionStorage.setItem('tracking_session_id', sid);
    }
    return sid;
};

const showSoftMessage = (msg) => {
    const toast = document.createElement('div');
    toast.className = 'fixed bottom-20 left-1/2 -translate-x-1/2 z-[10000] bg-black text-white px-6 py-3 rounded-full font-black text-[10px] uppercase tracking-[0.2em] shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] flex items-center gap-3 border-2 border-black animate-in fade-in slide-in-from-bottom-4 duration-300';
    toast.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-orange-500" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
        </svg>
        <span>${msg}</span>
    `;
    document.body.appendChild(toast);
    setTimeout(() => {
        toast.classList.add('opacity-0', 'duration-500');
        setTimeout(() => toast.remove(), 500);
    }, 4000);
};

window.trackEvent = async (eventName, userId = null, sessionId = null) => {
    try {
        const response = await fetch('/track', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                event_name: eventName,
                user_id: userId,
                session_id: sessionId || getSessionId()
            })
        });

        const data = await response.json();
        if (data.status === 'error' && data.message === 'Daily limit reached') {
            if (eventName === 'recording_started') {
                showSoftMessage("Please wait");
            } else {
                showSoftMessage("Daily limit reached");
            }
        }
    } catch (e) {
        console.error('Tracking failed:', e);
    }
};
