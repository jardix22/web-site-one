"#amazing".onClick(function(event) {
  event.stop();
  $$('h2')[0].fade();
});

"#time".onClick(function(event) {
  event.stop();
  $('msg').load("/profile/time");
});

"#server".onClick(function(event) {
  event.stop();
  $('msg').load("/profile/response");
});

"#reverse".onSubmit(function(event) {
  event.stop();
  this.send({
    onSuccess: function() {
      $('msg').update(this.responseText);
    }
  });
});
"#id1".onClick(function(event){
  event.stop();
  $('msg').load("/profile/1");
});

"#id2".onClick(function(event){
  event.stop();
  $('msg').load("/profile/2");
});
"#id3".onClick(function(event){
  event.stop();
  $('msg').load("/profile/3");
});

"#id4".onClick(function(event){
  event.stop();
  $('msg').load("/profile/4");
});

Xhr.Options.spinner = 'spinner';