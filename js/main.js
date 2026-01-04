/* ==========================================
   Main JS for Speyglo Landing
   - Handles loader timing and progressive reveal of the page
   - Includes accessibility checks and instructions on how to disable loader
   ========================================== */

(function(){
  'use strict'

  // Set current year in footer
  document.addEventListener('DOMContentLoaded', function(){
    var y = new Date().getFullYear();
    var el = document.getElementById('year');
    if(el) el.textContent = y;

    // Loader behavior
    var body = document.body;
    var loader = document.getElementById('loader');

    // If there's a data attribute on body to disable the loader, skip it
    // Usage: <body data-disable-loader>
    if(!loader || body.hasAttribute('data-disable-loader')){
      if(loader) loader.classList.add('hidden');
      return;
    }

    // Respect user's reduced-motion preference
    var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if(reduce){
      // Skip animation
      loader.classList.add('hidden');
      return;
    }

    // Duration should mirror --loader-duration in CSS (~ 2.6s by default)
    // If you change the CSS variable, change this timeout accordingly.
    var cssDuration = (getComputedStyle(document.documentElement).getPropertyValue('--loader-duration') || '2.6s').trim();
    var durationMS = 2600; // fallback
    // Support values like "2.6s" or "2600ms"
    var m = cssDuration.match(/([\d.]+)\s*(ms|s)/);
    if(m){
      durationMS = Math.round(parseFloat(m[1]) * (m[2] === 's' ? 1000 : 1));
    }

    // After the animation duration, fade out the loader
    setTimeout(function(){
      loader.classList.add('done');
      // Remove the loader from the DOM after transition to keep it clean
      setTimeout(function(){
        if(loader && loader.parentNode) loader.parentNode.removeChild(loader);
      }, 450);
    }, durationMS);

    // Add error handler for loader logo image - fallback if assets/images/L.svg fails to load
    var loaderImg = document.getElementById('loader-logo');
    if(loaderImg){
      loaderImg.addEventListener('error', function onLoaderError(){
        var src = loaderImg.getAttribute('src') || '';
        // Try with assets/images/ path first
        if(!src.includes('assets/images/')){
          loaderImg.src = 'assets/images/L.svg';
          return;
        }
        // Try filename only (for GitHub Pages or flat structures)
        if(src.includes('/')){
          loaderImg.src = src.split('/').pop();
          return;
        }
        // If still an SVG, try PNG variant
        if(/\.svg$/i.test(src)){
          loaderImg.src = src.replace(/\.svg$/i, '.png');
          return;
        }
      }, {once: true});
    }

    // Observe when social icons have loaded. Once loaded we remove the logo box
    // and expand the logo for a cleaner look. This improves the header after icons render.
    (function waitForSocialIcons(){
      var socialImgs = Array.prototype.slice.call(document.querySelectorAll('.social img'));
      var wrapper = document.querySelector('.brand-logo-wrapper');

      if(!wrapper) return; // nothing to do if wrapper missing

      if(socialImgs.length === 0){
        // No icons present — unbox immediately
        wrapper.classList.add('unboxed');
        return;
      }

      var loaded = 0;
      var done = function(){
        wrapper.classList.add('unboxed');
      };

      // Safety: if some images never fire load/error, use a timeout fallback (4s)
      var fallbackTimer = setTimeout(done, 4000);

      socialImgs.forEach(function(img){
        if(img.complete && img.naturalWidth !== 0){
          loaded++;
          if(loaded === socialImgs.length){
            clearTimeout(fallbackTimer);
            done();
          }
        } else {
          img.addEventListener('load', function(){
            loaded++;
            if(loaded === socialImgs.length){
              clearTimeout(fallbackTimer);
              done();
            }
          });
          img.addEventListener('error', function(){
            // count errors as 'loaded' to avoid blocking forever; fallback may still trigger
            loaded++;
            if(loaded === socialImgs.length){
              clearTimeout(fallbackTimer);
              done();
            }
          });
        }
      });
    })();

    // Add fallback for images when host only supports root-level files (no folders).
    // Strategy:
    // - On img error: try file name only (strip directories).
    // - If that fails, if .svg try .png variant.
    (function imageFallbacks(){
      function filenameOnly(url){
        if(!url) return null;
        try { var parts = url.split('/'); return parts.length ? parts[parts.length-1] : null; } catch(e){ return null; }
      }

      // Generic image error handler: try filename-only, then .svg -> .png
      document.querySelectorAll('img').forEach(function(img){
        img.addEventListener('error', function onErr(){
          if(img.dataset.__fallbackAttempted === '1'){
            img.removeEventListener('error', onErr);
            return;
          }
          img.dataset.__fallbackAttempted = '1';

          var src = img.getAttribute('src') || '';
          var flat = filenameOnly(src);
          if(flat && flat !== src){ img.src = flat; return; }

          if(/\.svg$/i.test(src)){
            img.src = src.replace(/\.svg$/i, '.png');
            return;
          }
          img.removeEventListener('error', onErr);
        }, {passive:true});
      });

      // Remember flat srcsets for <source> elements so we can apply them if needed
      document.querySelectorAll('picture source').forEach(function(source){
        var s = source.getAttribute('srcset') || '';
        var flat = filenameOnly(s);
        if(flat && flat !== s){
          source.setAttribute('data-srcset-original', s);
          source.setAttribute('data-srcset-flat', flat);
        }
      });

      // If a picture's <img> errors, try replacing its sources with flat variants and retry
      document.querySelectorAll('picture img').forEach(function(img){
        img.addEventListener('error', function tryPictureFlat(){
          var picture = img.parentElement;
          if(!picture) return;
          var sources = picture.querySelectorAll('source');
          var tried = false;
          sources.forEach(function(srcEl){
            var flat = srcEl.getAttribute('data-srcset-flat');
            if(flat){ tried = true; srcEl.setAttribute('srcset', flat); }
            else {
              var orig = srcEl.getAttribute('srcset') || '';
              var derived = filenameOnly(orig);
              if(derived && derived !== orig){ tried = true; srcEl.setAttribute('srcset', derived); }
            }
          });
          if(tried){
            var cur = img.getAttribute('src') || '';
            var flatImg = filenameOnly(cur);
            if(flatImg && flatImg !== cur){ img.src = flatImg; }
            else if(/\.svg$/i.test(cur)){ img.src = cur.replace(/\.svg$/i, '.png'); }
          }
        }, {passive:true});
      });

    })();

    // Optional: Expose helper to disable loader programmatically
    window.Speyglo = window.Speyglo || {};
    window.Speyglo.disableLoader = function(){
      if(loader) loader.classList.add('hidden');
    }

  });

})();
