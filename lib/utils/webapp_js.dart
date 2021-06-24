const hidePageContentsId = "EVERGLOT_HIDE_PAGE_CONTENTS_ID";
const hidePageContentsHtml =
    """<style id="$hidePageContentsId">body {display:none;}</style>""";

const tryShowPageContentsJsFunc = """
  (function() {
    function doShow() {
      var hider = document.getElementById('$hidePageContentsId');
      if (!hider) {
        console.log("Page contents are not hidden, cannot show them again");
        return false;
      }
      console.log("Page contents are hidden, showing them again");
      hider.remove();
    }
    if (document.readyState === "complete") {
      doShow();
    } else {
      document.addEventListener("DOMContentLoaded", function(_event) {
        doShow();
      }, { once: true });
    }
    return true;
  })
""";

const tryHidePageContentsJsFunc = """
  (function() {
    function doHide() {
      var hider = document.getElementById('$hidePageContentsId');
      if (hider) {
        console.log("Page contents already hidden, cannot hide them");
        return false;
      }
      console.log("Hiding page contents");
      document.write('$hidePageContentsHtml');
    }
    if (document.readyState === "complete") {
      doHide();
    } else {
      document.addEventListener("DOMContentLoaded", function(_event) {
        doHide();
      }, { once: true });
    }
    return true;
  })
""";

const initializeLocationChangeListenersJsFunc = """
  (function() {
    if (!window.locationChangeListenersInitialized) {
      history.pushState = ( f => function pushState(){
          var ret = f.apply(this, arguments);
          window.dispatchEvent(new Event('pushstate'));
          window.dispatchEvent(new Event('locationchange'));
          return ret;
      })(history.pushState);

      history.replaceState = ( f => function replaceState(){
          var ret = f.apply(this, arguments);
          window.dispatchEvent(new Event('replacestate'));
          window.dispatchEvent(new Event('locationchange'));
          return ret;
      })(history.replaceState);

      window.addEventListener('popstate',()=>{
          window.dispatchEvent(new Event('locationchange'))
      });

      window.addEventListener("locationchange", function() {
          WebViewLocationChange.postMessage(window.location.pathname)
      });
      window.locationChangeListenersInitialized = true;
    }
  })
""";
