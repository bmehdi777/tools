// ==UserScript==
// @name         Vim mode in review
// @namespace    http://tampermonkey.net/
// @version      2025-01-29
// @description  try to take over the world!
// @author       You
// @include      /^https:\/\/gitlab\.smartpanda-network\.fr\/.+merge_requests.+\/diffs
// @icon         https://www.google.com/s2/favicons?sz=64&domain=smartpanda-network.fr
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function() {
    'use strict';

    // observe when div is ready
    const divDiffContainer = document.querySelector("main");
    let vimModeHasRun = false;
    const observer = new MutationObserver(function(mutations, obs) {
        mutations.forEach(function(mutation) {
            if (mutation.type === "childList" && mutation.target?.id === "diffs" && !vimModeHasRun) {
                vimMode();
                obs.disconnect();
                vimModeHasRun = true;
            }
        });
    });

    observer.observe(divDiffContainer, {childList: true, subtree: true});

    function vimMode() {
        const isFileByFile = document.querySelector("[data-testid=file-by-file]").checked;
        if (isFileByFile) {
            window.addEventListener("keypress", (event) => {
                const nextBtn = document.querySelector("[data-testid=gl-pagination-next]");
                const prevBtn = document.querySelector("[data-testid=gl-pagination-prev]");
                const viewedBtn = document.querySelector("[data-testid=fileReviewCheckbox]");
                switch (event.code) {
                    case "KeyJ":
                        event.stopImmediatePropagation();
                        scrollBy(0,50);
                        break;
                    case "KeyK":
                        event.stopImmediatePropagation();
                        scrollBy(0,-50);
                        break;
                    case "KeyH":
                        event.stopImmediatePropagation();
                        prevBtn.click();
                        break;
                    case "KeyL":
                        event.stopImmediatePropagation();
                        nextBtn.click();
                        break;
                    case "Space":
                        event.preventDefault();
                        event.stopImmediatePropagation();
                        viewedBtn.click();
                        if (!event.shiftKey) {
                        // wait a bit... too quick otherwise
                            window.setTimeout(()=> {
                                nextBtn.click();

                            }, 200);
                        }
                        break;
                }
            }, true);
        }
    }
})();
