javascript:(function(){function%20b(g){var%20e=window;if(e.ZotonicImageClipper){e.ZotonicImageClipper.run()}else{var%20f=g.createElement("script");f.src="http://all.local:8000/lib/js/clipper.js?"+Math.floor((new%20Date()).getTime()/86400000);g.body.appendChild(f)}}b(document);for(var%20a=0;a<frames.length;++a){var%20d=frames[a];if(d.frameElement.tagName=="IFRAME"){continue}if(d.innerWidth<400||d.innerHeight<400){continue}b(d.document)}})();

