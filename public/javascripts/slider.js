$(document).onReady(function() {
	MySlider(6000);
});
var MySlider = function (interval) {
	var slides;
	var cnt;
	var amount;
	var i;

	function run () {
		// hiding previus image and showing next
		$(slides[i]).fade('out',2500);

		i++;
		if(i >= amount) i = 0;
		$(slides[i]).fade('in',2500);

		//updating counter
		cnt.text(i+1+' / '+amount);

		//loop
		setTimeout(run, interval);
	}

	slides = $('my_slider').children();
	cnt = $('counter');
	amount = slides.length;
	i=0;

	// updating counter
	cnt.text(i+1+' / '+amount);

	setTimeout(run, interval)
};