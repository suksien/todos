// public/javascripts/application.js
// the `$` sign is a jQuery object and we're passing it an anonymous function, which jQuery will call
$(function() {
  $("form.delete").submit(function(event) { // returning all forms where `class=delete`
    event.preventDefault(); // prevents the default behavior, which is submitting the form when the delete link is clicked
    event.stopPropagation(); // prevents this `event` from being interpreted by another page or the browser

    var ok = confirm("Are you sure? This cannot be undone!");
    if (ok) {
      var form = $(this);

      var request = $.ajax({
        url: form.attr("action"),
        method: form.attr("method")
      });

      request.done(function(data, textStatus, jqXHR) {
        if (jqXHR.status === 204) {
          form.parent("li").remove();
        } else if (jqXHR.status === 200) {
          document.location = data;
        }
      });
    }
  });

});