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

// showSoftMessage is now defined globally via window.showSoftMessage in the layout's unified toast system

// Tracking moved to application.html.erb for global layout access

