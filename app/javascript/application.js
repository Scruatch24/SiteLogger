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
    toast.className = 'fixed bottom-20 left-1/2 -translate-x-1/2 z-[10000] w-fit max-w-[90vw] bg-black text-white px-6 py-3 rounded-full font-black text-[10px] uppercase tracking-[0.2em] shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] flex items-center gap-3 border-2 border-black animate-in fade-in slide-in-from-bottom-4 duration-300';

    // Create icon
    const icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    icon.setAttribute('class', 'h-4 w-4 text-orange-500');
    icon.setAttribute('viewBox', '0 0 20 20');
    icon.setAttribute('fill', 'currentColor');
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('fill-rule', 'evenodd');
    path.setAttribute('d', 'M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z');
    path.setAttribute('clip-rule', 'evenodd');
    icon.appendChild(path);

    // Create text span (safe - no innerHTML)
    const span = document.createElement('span');
    span.textContent = msg;

    toast.appendChild(icon);
    toast.appendChild(span);
    document.body.appendChild(toast);
    setTimeout(() => {
        toast.classList.add('opacity-0', 'duration-500');
        setTimeout(() => toast.remove(), 500);
    }, 4000);
};

// Tracking moved to application.html.erb for global layout access

