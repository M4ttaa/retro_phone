let interval = null
let missing_call_number = 'no_misscall'
let dial_val = 0;
let first_click_dial = true;


const OnSomeoneCalling = (number) => {

    let html = `
        <h3 class="text-extra-sm ">
            ${number} Calling You...
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm" id="answer">
           Answer
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm right-1" id="decline">
            Decline
        </h3>
    `

    $('.phone-green-screen').html(html)
}


const DisplayDials = () => {

    let html = `
        <h3 class="text-extra-sm dials-input p-3">${dial_val}</h3>
        <h3 class="absolute bottom-0 text-extra-sm left-4" id="callnumber">
           Call
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm right-12" id="back-dial">
            Back
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm right-1" id="delete-dial">
            Delete
        </h3>
    `

    $('.phone-green-screen').html(html)
}


$(document).on('click', '#delete-dial', function (e) {
    let new_value = $('.dials-input').text().slice(0, $('.dials-input').text().length - 1);
    //console.log('new value : ', new_value)
    $('.dials-input').text(new_value)
    dial_val = new_value;
    //$('.dials-input').text('1621896827')

})

$(document).on('click', '#back-dial', function (e) {
    NoNotificationToDisplay()
})

$(document).on('click', '#callnumber', function (e) {
    
    dial_val = $('.dials-input').text()
    $.post('https://retro_phone/CallPerson', JSON.stringify({
        number: $('.dials-input').text()
    }), (data) => {
        OnCallingAPerson(data.person)
    })

})

$(document).on('click', '#decline', function (e) {
    $.post('https://retro_phone/DeclineCall', JSON.stringify({}))
})

$(document).on('click', '#answer', function (e) {
    $.post('https://retro_phone/AnswerCall', JSON.stringify({}))
})

$(document).on('click', '#close', function (e) {
    $.post("https://qb-inventory/CloseInventory", JSON.stringify({}));

    $.post('https://retro_phone/close', JSON.stringify({}))
})

$(document).on('click', '#cancel-call', function (e) {
    $.post('https://retro_phone/CancelCall', JSON.stringify({}))
})

$(document).on('click', '#call', function (e) {
    DisplayDials()
})




const OnCallingAPerson = (person) => {
    $('.phone-frame').css('display', 'block')

    let html = `
        <h3 class="text-extra-sm ">
            You Calling ${person}...
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm" id="cancel-call">
            Cancel
        </h3>
    `

    $('.phone-green-screen').html(html)
}


$(document).on('click', '.dials-group', function (e) {

    if ($(e.target).attr('data-num')) {
        if(first_click_dial){
            $('.dials-input').text("");
            first_click_dial = false

        }
        $('.dials-input').append($(e.target).attr('data-num'))
        dial_val = $('.dials-input').text();
    }
})

$(document).on('click', '#closecall', function (e) {

    $.post('https://retro_phone/CloseCall', JSON.stringify({}))
})

$(document).on('click', '#givenumber', function (e) {

    $.post('https://retro_phone/GivePhoneNumber', JSON.stringify({}))
})





const NoNotificationToDisplay = () => {

    let html = `
        <h3 class="text-extra-sm flex align-baseline">
            <span class="material-icons icon-sm mr-1">notifications</span>
            No activity to display</h3>
        <h3 class="absolute bottom-0 text-extra-sm right-1" id="close">
            Close
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm left-12" id="menu">
            Menu
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm left-4" id="call">
            Call
        </h3>    
    `
    $('.phone-green-screen').html(html)
}

$(document).on('click', '#menu', function (e) {
    Menu()
})


const MissingCall = () =>{

    missing_call_number = missing_call_number.toString()
    let num = missing_call_number.length >= 8 ? missing_call_number.slice(0, 7)+'...' : missing_call_number

    let html = `
        <h3 class="text-extra-sm flex align-baseline">
            <span class="material-icons icon-sm mr-1">notifications</span>
            missing call from ${num} </h3>

        <h3 class="absolute bottom-0 text-extra-sm right-1" id="close">
            Close
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm left-12" id="menu">
            Menu
        </h3>
        <h3 class="absolute bottom-0 text-extra-sm left-4" id="call">
            Call
        </h3>    
    `
    $('.phone-green-screen').html(html)
}


const Menu = () =>{
    
    let html = `

        <div class="max-h-8 overflow-y-auto px-2 ">
            <p class="text-extra-sm flex items-center mb-1" id="givenumber">
                Give your phone number
            </p>
        </div>
  
        
        <h3 class="absolute bottom-0 text-extra-sm right-12" id="back-dial">
            Back
        </h3>
   
    `
    $('.phone-green-screen').html(html)

}


const OpenPhone = (data) => {
    first_click_dial = true
    $.post("https://qb-inventory/CloseInventory", JSON.stringify({}));
    $('.phone-frame').show()
    if (data.type == 'NoNotificationToDisplay') {
        
        
        SlideUpAnimation('.phone-frame', [{
            y: 65
        }, {
            y: 4
        }]);

        if(dial_val != 0){
            DisplayDials()
        }else{
            NoNotificationToDisplay()
        }
    } else if (data.type == "OnCallingAPerson") {
        
        OnCallingAPerson()
    } else if (data.type == "OnSomeoneCalling") {
        SlideUpAnimation('.phone-frame', [{
            y: 65
        }, {
            y: 50
        }]);
        OnSomeoneCalling(data.number);
    } else if (data.type == "InCall") {
        InCall();


    } else if(data.type == 'MissingCall'){
        SlideUpAnimation('.phone-frame', [{
            y: 65
        }, {
            y: 4
        }]);
        if(dial_val != 0){
            DisplayDials()
        }else{
            MissingCall()

        }

    } else if(data.type == 'Dials'){
        DisplayDials()

    }
}


function sec2time(timeInSeconds) {
    var pad = function (num, size) {
            return ('000' + num).slice(size * -1);
        },
        time = parseFloat(timeInSeconds).toFixed(3),
        hours = Math.floor(time / 60 / 60),
        minutes = Math.floor(time / 60) % 60,
        seconds = Math.floor(time - minutes * 60),
        milliseconds = time.slice(-3);

    return Number(pad(hours, 2)) + ':' + Number(pad(minutes, 2)) + ':' + Number(pad(seconds, 2));
}

const InCall = (name) => {

    let html = `
    <h3 class="text-extra-sm flex align-baseline">
        <span class="material-icons icon-sm mr-1">phone</span>
        You're in call <span id="time">0:00</span></h3>
    
    <h3 class="absolute bottom-0 text-extra-sm left-1" id="closecall">
        Close Call
    </h3>
 
    `
    let startDate = new Date();
    // Do your operations

    $('.phone-green-screen').html(html)

    interval = setInterval(() => {
        let endDate = new Date();
        let seconds = (endDate.getTime() - startDate.getTime()) / 1000;
        $('#time').text(sec2time(seconds))
    }, 1000)

}

const ClosePhone = () => {
    dial_val = 0

    if (interval) {
        clearInterval(interval)
        interval = null;
    }
    $.post("https://qb-inventory/CloseInventory", JSON.stringify({}));

    SlideUpAnimation('.phone-frame', [{
        y: 65
    }, {
        y: 120
    }], function () {
        $('.phone-frame').hide();
        $('.phone-frame').css('transform', 'translateY(0)')
        NoNotificationToDisplay()
    });
}


function SlideUpAnimation(el, v, cb) {
    //Reverse the array

    //$(el).css('transform', 'translateY(55%)')
    // var reversed = JSON.parse(JSON.stringify(v)).reverse();

    $(v[0]).animate(v[1], {
        //The speed the element moves - lower is faster
        duration: 500,
        step: function (val) {
            //Adding the transform to your element
            $(el).css("transform", `translateY(${val}%)`);
        },
        done: function () {
            //Re-running the function but in reverse with the reverse we did above
            //SlideUpAnimation(reversed)
            if (cb) {

                cb()
            }

        }
    })
};





window.addEventListener("message", function (e) {
    const event = e.data;
    switch (event.action) {

        case "ACTION_DISPLAY":
            if (event.value.show) {
                $('.phone-frame').css('display', 'block')

                OpenPhone({
                    type: event.value.type,
                    number : event.value.number ? event.value.number :  ''
                })
            } else {
                ClosePhone()
            }

            break;
        case "ACTION_SET_MISSINGCALL":
            if(event.value.misscall){
                missing_call_number = event.value.misscall
            }
            break;
        case "INSERT_DIAL_INFO": 
            
            dial_val = event.value;
            break;
        default:
            break;
    }
});