using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;


var main_view, game_view;
var main_delegate, game_delegate;
var KEY_MAP = {
    Ui.KEY_POWER => "POWER",
    Ui.KEY_UP => "UP",
    Ui.KEY_DOWN => "DOWN",
    Ui.KEY_ENTER => "ENTER",
    Ui.KEY_ESC => "BACK",
    Ui.KEY_MENU => "MENU"
};

function pushView(view, delegate, transition){
    debug("Pushing view");
    Ui.pushView(view, delegate, transition);
}

function popView(transition){
    debug("Popping view");
    Ui.popView(transition);
}

function switchToView(view, delegate, transition){
    debug("Switching views");
    debug("Pop...");
    Ui.popView(transition);
    debug("...and Push.");
    Ui.pushView(view, delegate, transition);
}


class PackmanApp extends App.AppBase {

    function onStart() {
        main_view = new MainView();
        main_delegate = new MainDelegate();
        game_view = new GameView();
        game_delegate = new GameDelegate();
    }

    function onStop() {

    }

    function getInitialView() {
        return [main_view, main_delegate];
    }

}


class MainDelegate extends Ui.BehaviorDelegate {
    // TODO: add support for settings

    function onKey(keyevent){
        var keycode = keyevent.getKey();
        debug("Key Pressed: " + KEY_MAP[keycode]);
        if(keycode == Ui.KEY_ENTER){
            // pressing the enter key starts the app
            debug("Calling new_game()");
            game_view.new_game();
            debug("Pushing game_view");
            pushView(game_view, game_delegate, Ui.SLIDE_LEFT);
        }
    }
}


class GameDelegate extends Ui.BehaviorDelegate {
    function onKey(keyevt){
        var keycode = keyevt.getKey();
        if(keycode == Ui.KEY_ENTER){
            // if the enter key has been pressed during a game
            // and the game isn't over, then pause/unpause the game
            if(!game_view.game_over_loss){
                game_view.pause();
                return true;
            }
        }
        debug("Key Pressed: " + KEY_MAP[keycode]);
        return false;
    }

    function onMenu(){
        if(!game_view.is_paused){
            game_view.pause();
        }
        pushView(new Rez.Menus.GameMenu(), new GameMenuDelegate(), Ui.SLIDE_LEFT);
    }

    function onPreviousPage(){
        onMenu();
    }
}


class GameMenuDelegate extends Ui.MenuInputDelegate {
    function onMenuItem(item){
        if(item == :save){
            debug("Save and Quit");
            game_view.save_session();
            popView(Ui.SLIDE_RIGHT);
        }
        else if(item == :discard){
            debug("Discard and Quit");
            switchToView(new Ui.Confirmation("Are you sure?"), new ConfirmDiscard(), Ui.SLIDE_LEFT);
        }
        else if(item == :cancel){
            debug("Cancel");
            // go back to the game view
        }
    }
}


class ConfirmDiscard extends Ui.ConfirmationDelegate{
    function onResponse(response){
        if(response == Ui.CONFIRM_YES){
            debug("Discarding FIT session.");
            game_view.discard_session();
            popView(Ui.SLIDE_RIGHT);
        }
        else{
            debug("Returning to game menu.");
            game_delegate.onMenu();
        }
    }
}