import deimos.ncurses;
import std.string;

enum ColourPairs : int {
  MainBorder = 1,
    MainTitleText,
    StatusBar
    
    
    }

void initCurses()
{
  initscr;
  start_color;
  init_pair(ColourPairs.MainTitleText, COLOR_MAGENTA, COLOR_BLACK);
  init_pair(ColourPairs.MainBorder, COLOR_CYAN, COLOR_BLACK);
  init_pair(ColourPairs.StatusBar, COLOR_YELLOW, COLOR_BLUE);

}

  WINDOW* create_newwin(int height, int width, int starty, int startx, ColourPairs border, ColourPairs text, string title = "")
  {
    WINDOW* local_win;
    local_win = newwin(height, width, starty, startx);
    wattron(local_win, COLOR_PAIR(border));
    box(local_win, A_NORMAL , A_NORMAL);
    wattroff(local_win, COLOR_PAIR(border));
    wbkgd(local_win, COLOR_PAIR(text));
    if (title != "") {
      wattron(local_win, A_BOLD);
      mvwprintw(local_win, 0,cast(int)((width/2)-(title.length/2)), "%s", title.toStringz);
      wattroff(local_win, A_BOLD);

    }
    wrefresh(local_win);                    // Show that box
    return local_win;
  }
