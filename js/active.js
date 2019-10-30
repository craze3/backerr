$('document').ready(function(){


  //======> Testimonial Slider
  $('.testimonial-slider').slick({
    infinite:true,
    slidesToShow: 2,
    slidesToScroll: 1,
    dots:false,
    arrows: true,
    appendArrows: '.testimonial-slider-wrapper .slider-btns',
    prevArrow:'<button type="button" class="slick-prev"><i class="icon icon-tail-left"></i></button>',
    nextArrow:'<button type="button" class="slick-next"><i class="icon icon-tail-right"></i></button>',
    responsive: [
      {
        breakpoint: 991,
        settings: {
          slidesToShow: 2,


        }
      },
      {
        breakpoint: 768,
        settings: {
          slidesToShow: 1
        }
      },
      {
        breakpoint: 480,
        settings: {
          slidesToShow: 1,
          autoplay: true
        }
      }
    ]
  });



// Pricing toggle Functionality
  $("[class*='btn--toggle']").on('change',function(e){


      var getTarget = $(this).attr('data-tab-target');
      var inpSelect = $(this).children().children('input[type="checkbox"]');

      if($(inpSelect).is(':checked')){
          if($(getTarget).hasClass('monthly')){
              $(getTarget).removeClass('monthly');
              $(getTarget).addClass('yearly');

          }
      }else{
          // $(getTarget).removeClass('monthly');
          if($(getTarget).hasClass('yearly')){
              $(getTarget).removeClass('yearly');
              $(getTarget).addClass('monthly');

          }
      }


  })
})

// Mobile Menu Activation
$('.main-navigation').meanmenu({
    meanScreenWidth: "992",
    meanMenuContainer: '.mobile-menu',
    meanMenuClose: "<i class='icon icon-simple-remove'></i>",
    meanMenuOpen: "<i class='icon icon-menu-34'></i>",
    meanExpand: "",
});
