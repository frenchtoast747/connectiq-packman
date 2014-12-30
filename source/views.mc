using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Timer as Timer;
using Toybox.Attention as Attention;
using Toybox.Position as Position;
using Toybox.Math as Math;
// using Toybox.ActivityRecording as AR;


// a magic number to determine the amount of cushion
// TODO: should this be allowed as a setting? if
// results are ever published, then it might not be fair.
// then again, results could be published per level of difficulty
// easy, medium, hard, expert...
var STD_DEV_MULTIPLIER = 0.1;
// if a player allows a ghost to be close for 5 seconds
// then they will lose a life after the 5 seconds.
var MAX_GHOST_CLOSE_TICKS = 5;
// the number of lives before game over
var NUMBER_OF_LIVES = 3;
// number of ticks required for one packman dot
var TICKS_PER_DOT = 5;
// TODO: implement this
var DOTS_NEEDED_FOR_BONUS = 50;
// TODO: implement this
var TICKS_BETWEEN_SURPRISES = 30;

// various vibration lengths
var VIBPROF_10ms = new Attention.VibeProfile(50, 100);
var VIBPROF_100ms = new Attention.VibeProfile(50, 100);
var VIBPROF_500ms = new Attention.VibeProfile(50, 500);
// predefined vibration profiles. these should be
// passed in directly to Attention.vibrate()
var GHOST_CATCHUP_VIBRATE = [VIBPROF_100ms];
var LOSE_A_LIFE_VIBRATE = [VIBPROF_10ms, VIBPROF_10ms, VIBPROF_10ms];
var GAME_OVER_VIBRATE = [VIBPROF_500ms];

// create tone aliases that make sense in the terms of this app
// var GHOST_CATCHUP_TONE = Attention.TONE_DISTANCE_ALERT;
// var GAME_OVER_TONE = Attention.TONE_FAILURE;
// var LOSE_A_LIFE_TONE = Attention.TONE_INTERVAL_ALERT;

// globals that store information about the current device
var device_width = 0;
var device_height = 0;
// the x coordinate for device center
var center_x = 0;
// the y coordinate for device center
var center_y = 0;

// used to determine where to put text that appears above
// and below packman.
// gets initialized in the main view
var top_text_y = 0;
var bottom_text_y = 0;

// the images
var packman_open, packman_close;
// width and height are 32 pixels
var PACKMAN_IMAGE_SIZE = 32;
var PACKMAN_HALF_IMAGE_SIZE = PACKMAN_IMAGE_SIZE / 2;

// fractional optimization?
var TWO_THIRDS = 2.0 / 3.0;


// a toggle switch to determine which image to draw
var packman_mouth_open = true;
// packman is drawn in both the Main view and the Game
// view. This function is used in both.
function drawPackman(dc){
    // @param dc, the Drawing Context
    var image = packman_close;
    if(packman_mouth_open){
        image = packman_open;
    }
    packman_mouth_open = !packman_mouth_open;
    dc.drawBitmap(center_x - PACKMAN_HALF_IMAGE_SIZE,
                  center_y - PACKMAN_HALF_IMAGE_SIZE, image);
}


class GameView extends Ui.View {
    // ActivityRecording session from createSession()
    // var session;
    // a Timer.Timer() used to update game information
    var game_timer;
    
    // information for the heart resource image
    var heart_image;
    var HEART_SIZE = 16;
    var HALF_HEART_SIZE = HEART_SIZE / 2;
    // amount of spacing between the heart images
    var HEART_SPACING = 5;
    // how far from the top of the device
    var HEART_TOP_PADDING = 2;
    // how far from the right edge of the device
    var HEART_RIGHT_PADDING = 2;
    
    // like the heart image above
    var ghost_image;
    var GHOST_SIZE = 32;
    var HALF_GHOST_SIZE = GHOST_SIZE / 2;
    var GHOST_LEFT_PADDING = 10;
    
    // the size of the dot that packman eats
    var DOT_RADIUS = 10;
    // the amount of spacing between each position
    // in the dot animation (as it's coming towards packman)
    var DOT_SPACING = 20;
    
    // the dot score counter in the top left corner
    var DOT_COUNT_RADIUS = 5;
    var DOT_COUNT_PADDING = HEART_TOP_PADDING;
    // the x coordinate for where to start drawing the circle
    var DOT_COUNT_X = DOT_COUNT_RADIUS + DOT_COUNT_PADDING;
    // the y coordinate for where to start drawing the circle
    var DOT_COUNT_Y = DOT_COUNT_RADIUS + DOT_COUNT_PADDING;
    // the padding between the dot and the count text
    var DOT_COUNT_TEXT_PADDING = 10;
    // the x coordinate for where to start drawing the text
    var DOT_COUNT_TEXT_X = DOT_COUNT_RADIUS + DOT_COUNT_RADIUS + DOT_COUNT_PADDING + DOT_COUNT_TEXT_PADDING;
    // the y coordinate for where to start drawing the text
    var DOT_COUNT_TEXT_Y = DOT_COUNT_RADIUS + DOT_COUNT_RADIUS + DOT_COUNT_PADDING;
    
    // gets set in the position_callback
    var current_speed;
    // these vars are needed for the
    // rolling std deviation calculations
    var tick_count, speed_sum, speed_sum_squared;
    // the number of dots collected during gameplay
    var dot_count;
    // the number of times a user has used a bonus
    var bonuses_used;
    // is the ghost about to eat you?
    var is_ghost_close;
    // number of ticks that the ghost has been close
    var is_ghost_close_count;
    // the number of lives the player currently has
    var lives;
    // did the player run out of lives?
    var game_over_loss;
    // is the game currently paused?
    var is_paused;
    
    function initialize(){
        // the constructor
        debug("Creating game timer");
        game_timer = new Timer.Timer();
        
        // debug("Creating activity session");
        // session = AR.createSession({
            // :name => "Packman Game"
        // });
    }
    
    function new_game(){
        debug("Initializing game variables");
        is_paused = false;
        game_over_loss = false;
        current_speed = 0;
        tick_count = 0;
        speed_sum = 0.0;
        speed_sum_squared = 0.0;
        dot_count = 0;
        bonuses_used = 0;
        is_ghost_close = false;
        is_ghost_close_count = 0;
        lives = NUMBER_OF_LIVES;
    }
    
    function start(){
        is_paused = false;
        Position.enableLocationEvents(
            Position.LOCATION_CONTINUOUS, method(:position_callback));
        debug("Starting game timer.");
        // fire the main game loop every second
        game_timer.start(method(:tick), 1000, true);
        // start recording the activity
        // session.start();
        // call tick() so that the initial setup is ready to be drawn for
        // the following update request
        tick();
        Ui.requestUpdate();
    }
    
    function onLayout(dc) {
        // initialize the image resources
        debug("Getting heart_image");
        heart_image = Ui.loadResource(Rez.Drawables.heart);
        debug("Getting ghost_image");
        ghost_image = Ui.loadResource(Rez.Drawables.ghost);
    }
    
    function onShow(){
        debug("Starting game...");
        // this will get fired under two scenarios:
        // 1) Start of a new game
        // 2) Going in to the game menu (via menu or previousPage buttons)
        //    and returning. It's possible to go into the game menu
        //    in a Game Over scenario and hit cancel to return to the
        //    game over screen. The check for game over prevents the
        //    game from starting again while in Game Over mode.
        if(!game_over_loss){
            start();
        }
    }
    
    function onHide(){
        // this is fired when the menu is brought up
        debug("GameView onHide().");
        shutdown();
    }

    function save_session(){
        // a method to allow saving from the delegates.
        // saves the FIT file.
        // debug("Saving session.");
        // if(session.isRecording()){
            // session.stop();
        // }
        // session.save();
    }
    
    function discard_session(){
        // a method to allow discarding from the delegates.
        // discards the FIT file.
        // debug("Discarding session.");
        // if(session.isRecording()){
            // session.stop();
        // }
        // session.discard();
    }
    
    function position_callback(position){
        // fired when Position.enableLocationEvents returns with data
        // and sets the current speed used within the tick()
        debug("Position Callback");
        current_speed = position.speed;
    }
    
    function pause(){
        // pauses the game if running.
        // unpauses the game if already paused
        if(!is_paused){
            // stop both the game timer and the FIT recording
            // session.
            game_timer.stop();
            // session.stop();
            // disable the position callback (this is just resource saving)
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            // this is used in the onUpdate() function
            // to draw "Paused" on the screen
            is_paused = true;
            // request an update to draw the "Paused"
            Ui.requestUpdate();
        }
        else{
            is_paused = false;
            // start the game again
            start();
        }
    }
    
    
    // this function uses the player's average speed and standard deviation
    // to calculate when the ghost is "catching up". if the player's current
    // speed drops below the average speed minus the standard deviation
    // (multiplied by some factor) then they ghost is "catching up".
    // The player has 5 seconds (MAX_GHOST_CLOSE_TICKS) to speed up and get
    // out of "catching up" mode to prevent the ghost from catching them and
    // losing a life. Once the user speeds up to go faster than the lower
    // standard deviation bound, then the player leaves "catching up" mode.
    function tick(){
        // the main game logic goes here
        tick_count += 1;
        // increment the dots collected count
        if(tick_count % TICKS_PER_DOT == 0){
            dot_count += 1;
        }
        debug("===================================");
        
        var speed = current_speed;
        // let 'n' be the sample size (tick_count),
        // S1 be the sum, and S2 be the sum all of
        // all squared sums, then the mean can be found
        // by: mu_hat = S1 / n
        // and the variance is given by:
        // sigma_squared_hat = (S2 / n) - (mu_hat ^ 2)
        // and finally the standard deviation:
        // Math.sqrt(sigma_squared_hat)
        speed_sum += speed;
        var avg_speed = speed_sum / tick_count;
        speed_sum_squared += speed * speed;
        var std_dev = Math.sqrt(
            (speed_sum_squared / tick_count) - (avg_speed * avg_speed));
        
        // the multiplier accounts for potential
        // mode differences
        var lower_bound = avg_speed - (STD_DEV_MULTIPLIER * std_dev);

        debug("Dots " + dot_count);
        debug("Speed: " + speed);
        debug("Avg Speed: " + avg_speed);
        debug("Difference: " + (speed - avg_speed));
        debug("Std Deviation: " + std_dev);
        debug("Lower Bound: " + lower_bound);
        debug("Current Speed < Lower Bound: " + (speed < lower_bound));

        // if the user is running too slow,
        // then the chasing ghost is catching up
        if(speed < lower_bound){
            handle_catchup_ghost();
        }
        else{
            // exit "catching up" mode
            reset_catch_up_ghost_values();
        }
        // ask to draw the new information
        Ui.requestUpdate();
    }
    
    function get_bonuses_available(){
        // TODO: the thing that uses this hasn't been implemented yet.
        // The total dot count modulus number of dots needed for a bonus
        // will give the number of bonus rounds earned. Then, subtracting
        // the number of bonuses already used will return the number
        // of available bonuses.
        return (dot_count % DOTS_NEEDED_FOR_BONUS) - bonuses_used;
    }
    
    function reset_catch_up_ghost_values(){
        is_ghost_close = false;
        is_ghost_close_count = 0;
    }
    
    function handle_catchup_ghost(){
        // the ghost is getting closer.
        // after a certain period of time in
        // this state will cause the player
        // to lose a life
        if(!is_ghost_close){
            // if this is the first time is_ghost_close
            // has been set to true warn the user.
            // This prevents from a warning occurring every tick
            // for MAX_GHOST_CLOSE_TICKS
            debug("WATCH OUT!!! THE GHOST IS GOING TO GET YOU!!!");
            if(Attention has :playTone){
                Attention.playTone(Attention.TONE_DISTANCE_ALERT);
            }
            if(Attention has :vibrate){
                Attention.vibrate(GHOST_CATCHUP_VIBRATE);
            }
        }
        is_ghost_close = true;
        is_ghost_close_count += 1;
        if(is_ghost_close_count > MAX_GHOST_CLOSE_TICKS){
            lose_a_life();
            // reset the counters so that catchup mode is exited
            reset_catch_up_ghost_values();
        }
    }
    
    function shutdown(){
        // called when the game is over or when the menu is displayed
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        game_timer.stop();
        // session.stop();
        // make sure to draw anything new
        Ui.requestUpdate();
    }
    
    function game_over(){
        // the player has lost all of their lives.
        // go into game over mode and display final
        // statistics on the screen
        debug("================");
        debug("Game Over :(");
        // mark this game as a loss
        game_over_loss = true;
        // the final image looks better if
        // packman's mouth is left open
        packman_mouth_open = true;
        // play the bummer sound and vibrate
        if(Attention has :playTone){
            Attention.playTone(Attention.TONE_DISTANCE_ALERT);
        }
        if(Attention has :vibrate){
            Attention.vibrate(GAME_OVER_VIBRATE);
        }
        // clean up and draw
        shutdown();
    }
    
    function lose_a_life(){
        // decrement the users life count
        // and check to see if the game should
        // end.
        lives -= 1;
        if(lives <= 0){
            game_over();
        }
        else{
            if(Attention has :playTone){
                Attention.playTone(Attention.TONE_DISTANCE_ALERT);
            }
            if(Attention has :vibrate){
                Attention.vibrate(LOSE_A_LIFE_VIBRATE);
            }
            debug("Ouch! He got you. You have " + lives + " live(s) left.");
        }
    }
    
    function drawLives(dc){
        var y = HEART_TOP_PADDING;
        var x = device_width - HEART_SIZE - HEART_RIGHT_PADDING;
        // draw each heart from right to left
        for(var i=0; i<lives; i++){
            dc.drawBitmap(x, y, heart_image);
            x = x - (HEART_SPACING + HEART_SIZE);
        }
    }
    
    function drawDot(dc){
        // the dot animation that packman eats
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        var modulus = tick_count % TICKS_PER_DOT;
        var multiplier = TICKS_PER_DOT - modulus;
        var x = multiplier * DOT_SPACING - (DOT_RADIUS + DOT_RADIUS);
        // packman is positioned at the center. this draws the first dot
        // relative to the center position so that the last dot ends up
        // in the middle of packman
        dc.fillCircle(center_x + x, center_y, DOT_RADIUS);
    }
    
    function drawDotCount(dc){
        // display the user's score (in dots) in the top
        // left corner
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.fillCircle(DOT_COUNT_X, DOT_COUNT_Y, DOT_COUNT_RADIUS);
        dc.drawText(DOT_COUNT_TEXT_X, DOT_COUNT_TEXT_Y, Gfx.FONT_SMALL,
                    "" + dot_count, Gfx.TEXT_JUSTIFY_LEFT);
    }
    
    function drawGhost(dc){
        // set the x value as some multiple of the ghost count
        // so that it appears that the ghost is getting closer
        // to packman
        dc.drawBitmap(GHOST_LEFT_PADDING * (is_ghost_close_count + 1),
                      center_y - HALF_GHOST_SIZE, ghost_image);
    }
    
    function onUpdate(dc) {
        // clear the screen and redraw
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.clear();
        // don't draw the lives or the dot count
        // if this is Game Over
        if(!game_over_loss){
            drawLives(dc);
            drawDotCount(dc);
        }
        // don't draw the animation dot if this is Game Over or paused
        if(!is_paused && !game_over_loss){
            drawDot(dc);
        }
        // if this is not Game Over and is paused, draw "Paused"
        if(is_paused && !game_over_loss){
            dc.drawText(center_x, center_y, Gfx.FONT_MEDIUM, "Paused",
                        Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
        // otherwise draw Packman
        else{
            drawPackman(dc);
        }
        // If this is Game Over inform the user and draw their
        // total dot count score below packman
        if(game_over_loss){
            dc.drawText(center_x, top_text_y, Gfx.FONT_MEDIUM,
                        "Game Over", Gfx.TEXT_JUSTIFY_CENTER);
            dc.drawText(center_x, bottom_text_y, Gfx.FONT_MEDIUM,
                        "Dots: "  + dot_count, Gfx.TEXT_JUSTIFY_CENTER);
        }
        // if the ghost is in catchup mode, draw it
        if(is_ghost_close){
            drawGhost(dc);
        }
        if(HW_DEBUG){
            dc.drawText(10, device_height - 10, Gfx.FONT_MEDIUM,
                        current_speed + "m/s", Gfx.TEXT_JUSTIFY_LEFT);
        }
    }
}


class MainView extends Ui.View {
    var timer;
    
    function initialize(){
        // an animation timer to draw packman
        // opening and closing his mouth
        timer = new Timer.Timer();
    }
    
    function onShow(){
        debug("Starting main animation timer.");
        timer.start(method(:request_update), 300, true);
    }
    
    function onHide(){
        debug("Hiding main view");
        timer.stop();
    }
    
    function request_update(){
        Ui.requestUpdate();
    }
    
    function onLayout(dc){
        // the packman images are being loaded once here 
        // and are shared with the GameView
        packman_open = Ui.loadResource(Rez.Drawables.packman_open);
        packman_close = Ui.loadResource(Rez.Drawables.packman_close);
        
        // set the device information
        device_width = dc.getWidth();
        device_height = dc.getHeight();
        center_x = device_width / 2;
        center_y = device_height / 2;
        
        // set the y value for text that appears above packman.
        // the bottom of the top text is placed 2/3 of the way
        // between the top of the device and the top of packman's head
        var top_of_image = center_y - PACKMAN_HALF_IMAGE_SIZE;
        top_text_y = TWO_THIRDS * top_of_image;
        
        // set the y value for text that appears below packman.
        // the bottom of the bottom text is placed 2/3 of the way
        // between the bottom of packman and the bottom of the device
        var bottom_of_image = center_y + PACKMAN_HALF_IMAGE_SIZE;
        bottom_text_y = (TWO_THIRDS * (device_height - bottom_of_image)) + bottom_of_image;
    }
    
    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.clear();
        
        // the main screen
        dc.drawText(center_x, top_text_y,
                    Gfx.FONT_MEDIUM, "Packman", Gfx.TEXT_JUSTIFY_CENTER);
        drawPackman(dc);
        dc.drawText(center_x, bottom_text_y,
                    Gfx.FONT_MEDIUM, "Press Start", Gfx.TEXT_JUSTIFY_CENTER);
    }
}