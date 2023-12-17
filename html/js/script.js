/*
    Plz don't steal.
*/

/*------------------------------------------------------------------------------------
	Constants
------------------------------------------------------------------------------------*/

const resourceName         = "prp-policedispatch";
const resourceNotification = "prp-notify";
const eventExpiry = 600;
const respondDoubleTap = 400;

const elements = 
{
    dispatchWrapper: $( ".wrapper" ),
    movingWrapper:  $(".movingFrame"), 
    history: $('.history'),
    historyEmpty: $('#historyEmpty'),
    viewPort: $(".view"),
    dispatch: $("#dispatch"),
    up: $("#up"),
    code: $("#code"),
    location: $("#location"),
    peopleTalking: $("#peopleTalking")
}

const defaultSettings = 
{
    customPosition: null,
    customSize: null,
    callSigns: {}
}  

const dispatchEvent =
{
    responders: 0,
    hasResponded: false
}

/* Should probably come up with a better way to match these */
const dispatchEventIcons = 
{
    "default": "fas fa-info-circle",
    "10-52 Ambulance Required": "fas fa-ambulance",
    "10-13 Shots Fired": "fas fa-exclamation-triangle",
    "10-13 Driveby Shooting": "fas fa-exclamation-triangle",
    "10-99 Car Jacking": "fas fa-car",
    "10-99 Stolen Car": "fas fa-car",
    "10-78A PANIC BUTTON": "fas fa-dizzy" 
}

/*------------------------------------------------------------------------------------
	Variables
------------------------------------------------------------------------------------*/

var currentState = 
{
    power: false,
    dragging: true,
    selected: null,
    lastID: null,
    lastTap: 0,
    lastYTap: 0,
}

var history = {};
var userSettings = {}

function init() 
{
    var settings = window.localStorage.getItem(resourceName);

    if(isJSON(settings))
    {
        userSettings = JSON.parse(settings);
    }

    userSettings = $.extend({}, defaultSettings, userSettings);

    if(userSettings.customPosition)
    {
        elements.dispatchWrapper.css(userSettings.customPosition);
    }
    
    if(userSettings.customSize)
    {
        elements.dispatchWrapper.css(userSettings.customSize);
    }

    elements.dispatchWrapper.draggable(
    {
        containment: elements.viewPort,
        scroll: false,
        disabled: true,
        start: function() 
        {
            $(this).addClass("moving");
        },
        stop: function() 
        {
            var position = 
            {
                left: $(this).css("left"),
                top: $(this).css("top")
            }

            $(this).removeClass("moving");
            userSettings.customPosition = position;

            saveSettings();
        }
    });


    elements.dispatchWrapper.resizable(
    {
        containment: elements.viewPort,
        disabled: true,
        maxHeight: 720,
        maxWidth: 1280,
        minHeight: 150,
        minWidth: 200,
        start: function() 
        {
            $(this).addClass("moving");
        },
        stop: function() 
        {
            var size = 
            {
                width: $(this).css("width"),
                height: $(this).css("height")
            }

            $(this).removeClass("moving");
            userSettings.customSize = size;

            saveSettings();
        }
    });

    elements.viewPort.mousedown(function (ev) 
    {
        if (ev.which == 3)
        {
            /* Right clicked on view, disable moving. */
            $.post(`http://${resourceName}/focusoff`, JSON.stringify({}));
        }
    });

    setInterval(refresh, 10000);
}

function setPower(requestedPower) 
{
    if (requestedPower) 
    {
        elements.dispatchWrapper.addClass("enabled");
        elements.peopleTalking.html("");
        currentState.power = requestedPower;
        $.post(`http://${resourceName}/syncState`, JSON.stringify({enabled: true}));
    }
    else 
    {
        elements.dispatchWrapper.removeClass("enabled");
        elements.peopleTalking.html("");
        currentState.power = requestedPower;
        $.post(`http://${resourceName}/syncState`, JSON.stringify({enabled: false}));
    }
}

function setDraggable(drag) 
{
    currentState.dragging = drag;

    elements.dispatchWrapper.draggable({disabled: !currentState.dragging});
    elements.dispatchWrapper.resizable({disabled: !currentState.dragging});

    if (currentState.dragging) 
    {
        elements.movingWrapper.addClass("enabled");
    }
    else 
    {
        elements.movingWrapper.removeClass("enabled");
    }
}

function fireEvent(data) 
{
    data = $.extend(true, {}, dispatchEvent, data);

    data.id = data.uniqueid;

    if(data.location.length > 30)
    {
        data.location = data.location.slice(0, 25) + "..";
    }

    /* Check if entry exists with same id */
    if (! history[data.id])
    {
    	/* Get time in unix epoch */
        data.time = new Date().getTime() / 1000;

        if(Object.keys(history).length == 0) 
        {
            elements.historyEmpty.hide();
        }

        history[data.id] = data;
        currentState.lastID = data.id;

        var selectEntry = false;

        if(! $(".selected").length || ( $(".entry").first().hasClass("selected") && ! $(".entry").first().hasClass("show-details")) )
        {
            selectEntry = true;
        }

        if (dispatchEventIcons[data.title])
        {
            icon = dispatchEventIcons[data.title];
        }
        else
        {
            icon = dispatchEventIcons["default"];
        }

        if(data.distance > 6)
        {
            data.distance = "> 6";
        }

        if (data.title.substr(0, 2) == "10")
        {
            var callSign = data.title.substr(0,data.title.indexOf(' '));
            var message = data.title.substr(data.title.indexOf(' ')+1);

            header = `<span class="call-sign"> ${callSign}</span> <span class="call-sign">${data.department}</span> ${message}`
        }
        else
        {
            header = `<span class="call-sign"><i class="${icon} fa-fw"></i></span> <span class="call-sign">${data.department}</span> ${data.title}`
        }
        
        let responderText = ""

        if (data.maxUnits != undefined && data.maxUnits > 0)
        {
            //responderText = '<i class="fas fa-arrow-circle-right"></i>' + " 0 / " + (data.maxUnits)
        }

        var elem = $(`
        <div data-id='${data.id}' class="entry priority-${data.priority}">
            <div class="info">
                <div class="left">
                    ${header} <span class="responders">${responderText}</span>
                    <br><i class="fas fa-location-arrow fa-fw"></i> ${data.location} (${data.distance})
                </div>
                <div class="right">
                    #${data.id} <br>
                    <span class="time">Just now</span>
                </div>
            </div>
            <div class="details">${data.description}
                <div class="responderContainer">
                </div>
            </div>
        </div>`);

        elements.history.prepend(elem);
        
        if (selectEntry || (data.priority && (data.priority == 1 || data.priority == 3)))
        {
            navigateTo(data.id);
        }
        else
        {
            navigateTo(currentState.selected);
            elements.up.show();
        }
    }
    else
    {
        console.log("Throwing an event with the same ID you fucking retard.");
    }

}

function refresh() 
{
    /* Get time in unix epoch */
    time = new Date().getTime() / 1000;

    /* Loop through each item in history */
    Object.keys(history).forEach(function (key)
    {
        entry = $('[data-id="'+key+'"]');

        if (entry.length)
        {
            diff = (time - history[key].time);

            if (diff > 60) 
            {
                if ( ( ( history[key].hasResponded == false && diff > eventExpiry) 
                     || (history[key].hasResponded == true && diff > eventExpiry*4)) 
                     && ! (key == currentState.selected && entry.hasClass("show-details"))) 
                {
                    if (history[key].id == currentState.lastID)
                    {
                        elements.up.hide();
                    }

                    /* Check if we deleted the selected entry */
                    delete history[key];
                    entry.remove();
                    	
                    if(Object.keys(history).length == 0) 
                    {
                        elements.historyEmpty.show();
                    }
                }
                else
                {
                    entry.find(".time").text(Math.ceil(diff/60) + " mins ago");
                }
            }
            else if (diff >= 20)
            {
                entry.find(".time").text("< 1 min ago");
            } 
        }
        else
        {
            /* Exists in the array but not on the dom, matchey matchey */
            delete history[key];
        }
    });
}

$(function() 
{
    init();

    window.addEventListener('message', function(event) 
    {
        var type = event.data.type; 
        var state = event.data.state; 

        /* NUI events */
        switch ( type ) 
        {
            case "state":
                setPower(state);
                break;

            case "event":
                fireEvent(event.data);
                break;

            case "move":
                setDraggable(state);
                break;

            case "navigation":
                if (state == 0 || state == 1) 
                {
                    /* Up / Down */
                    navigate(state);
                }
                else if (state == 2) 
                {
                    /* Enter / Right */
                    if ($(".show-details").length) 
                    {
                        $(".show-details").removeClass("show-details");
                    }
                    else 
                    {
                        $(".selected").addClass("show-details");
                    }

                    /* Ugly hack to make selected item is completely in view */
                    navigateTo(currentState.selected);
                }
                else if (state == 3) 
                {
                    var currentTime = new Date().getTime();

                    // Check if double tap.
                    if ( (currentTime - currentState.lastTap) < respondDoubleTap )
                    {
                        /* G / Respond */
                        if (history[currentState.selected]) 
                        {
                            var response = 
                            {
                                event: history[currentState.selected],
                            };

                            if (history[currentState.selected].hasResponded == false)
                            {
                                $.post(`http://${resourceName}/respond`, JSON.stringify(response));
                            }
                            else
                            {
                                $.post(`http://${resourceName}/setGPS`, JSON.stringify(response));
                            }
                            
                            history[currentState.selected].hasResponded = true;
                        }

                        currentState.lastTap = 0;
                    }
                    else
                    {
                        currentState.lastTap = currentTime;
                    }
                }   
                else if (state == 4) 
                {
                    var currentTime = new Date().getTime();

                    // Check if double tap.
                    if ( (currentTime - currentState.lastYTap) < respondDoubleTap )
                    {
                        /* G / Respond */
                        if (history[currentState.selected]) 
                        {
                            var response = 
                            {
                                event: history[currentState.selected],
                            };

                            if (history[currentState.selected].hasResponded)
                            {
                                $.post(`http://${resourceName}/unrespond`, JSON.stringify(response));
                            }
                            
                            history[currentState.selected].hasResponded = false;
                        }

                        currentState.lastYTap = 0;
                    }
                    else
                    {
                        currentState.lastYTap = currentTime;
                    }
                }   
                break; 
            case "response":
                var localId = event.data.uniqueid;
                var callSign = event.data.callSign;

                if (history[localId])
                {
                    var element = $('[data-id="'+localId+'"]');
                    history[localId].responders++;
                    
                    if(element.length)
                    {
                        var elem = $(`
                        <span class="responder">${callSign}</span> `);

                        element.find(".responderContainer").append(elem);

                        if (history[localId].maxUnits != undefined && history[localId].maxUnits > 0)
                        {
                            element.find(".responders").html('<i class="fas fa-arrow-circle-right"></i> ' + history[localId].responders + " / " + history[localId].maxUnits);
                        }
                        else
                        {
                            element.find(".responders").html('<i class="fas fa-arrow-circle-right"></i> ' + history[localId].responders);
                        }
                    }
                }

                break;
                case "unresponse":
                    var localId = event.data.uniqueid;
                    var callSign = event.data.callSign;

                    if (history[localId])
                    {
                        var element = $('[data-id="'+localId+'"]');

                        if(element.length)
                        {
                            element.find(".responderContainer span").each(function()
                            {
                                if ($(this).html() == callSign)
                                {
                                    $(this).remove();
                                    history[localId].responders--;

                                    if (history[localId].maxUnits != undefined && history[localId].maxUnits > 0)
                                    {
                                        element.find(".responders").html('<i class="fas fa-arrow-circle-right"></i> ' + history[localId].responders + " / " + history[localId].maxUnits);
                                    }
                                    else
                                    {
                                        element.find(".responders").html('<i class="fas fa-arrow-circle-right"></i> ' + history[localId].responders);
                                    }
                                }
                            });
                        }
                    }
    
                    break;                
            case "visible":
                if (currentState.power)
                {
                    if (state)
                    {
                        elements.dispatchWrapper.addClass("enabled");
                    }
                    else
                    {
                        elements.dispatchWrapper.removeClass("enabled");
                    }
                }
                break;
            case "addRadioPerson":
                if (currentState.power)
                {
                    if (! $( "#talker-"+event.data.id ).length ) 
                    {
                        var element = "<div class='talker' id='talker-" + event.data.id + "' class=talker'>\
                    <i class='fas fa-volume-up'></i> " + event.data.name + "</div>";
                    
                        elements.peopleTalking.append(element );
                    }
                }
                break;
            case "removeRadioPerson":
                if (currentState.power)
                {
                    if ( $( "#talker-"+event.data.id ).length ) 
                    {
                        $( "#talker-"+event.data.id ).remove();
                    }
                }
                break;
            case "clearSpeakers":
                elements.peopleTalking.html("");
                break;
            /* default */
            
            default:
                break;
            }
    });
});

function navigateTo(id)
{
    var element = $('[data-id="'+id+'"]');

    if (element.length)
    {
        if (id != currentState.selected)
        {
            $(".show-details").removeClass("show-details");

            currentState.selected = id;
            entry = history[currentState.selected];
            
            //elements.code.text(entry.title);
            //elements.location.text(entry.location);
    
            $(".selected").removeClass("selected");
            $(element).addClass("selected");

            if(id == currentState.lastID)
            {
                elements.up.hide();
            }
        }
        

        elements.history.animate(
        {
            scrollTop: elements.history.scrollTop() + (element.position().top - elements.history.position().top) - (elements.history.height()/2) + (element.height()/2) 
        }, 200);
    }
}

function navigate(direction) 
{
    /* Eventually change this to search via the array */
    var current = $(".selected");
    
    if(! current.length ) 
    {
        /* No currently selected, select first one. */
        current = $(".entry:first");
    }
    else if (direction == 1) 
    {
        /* Going down, check if we can go down */
        next = current.next(".entry");

        if (next.length)
        {
            current = next;
        }
    }
    else if (direction == 0)
    {
        /* Going up, check if we can go up */
        prev = current.prev(".entry");
        
        if (prev.length) 
        {
            current = prev;
        }
    }

    navigateTo(current.data("id"));
}

function notify(type, title, message, timeout = 5000, sticky = false, icon = "tablet") 
{
    var notification = 
    {
      message: message,
      title: title,
      type: type,
      sticky: sticky,
      icon: icon,
      timeout: timeout
    };
  
    $.post(`https://${resourceNotification}/notification`, JSON.stringify(notification));
}

function saveSettings()
{
    window.localStorage.setItem(resourceName, JSON.stringify(userSettings));
}

/* Off StackOverflow, dirty but works */
function isJSON(str) 
{
    try 
    {
        return (JSON.parse(str) && !!str);
    } 
    catch (e) 
    {
        return false;
    }
}

$(function() 
{
    $.post(`http://${resourceName}/nuiReady`, JSON.stringify({}));
});