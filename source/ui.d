import deimos.ncurses;
import std.string;

enum ColourPairs : int {
  MainBorder = 1,
  StatusText,
    a,
    b,
    
    }

void initCurses()
{
  initscr;
  start_color;
  init_pair(ColourPairs.StatusText, COLOR_MAGENTA, COLOR_BLACK);
  init_pair(ColourPairs.MainBorder, COLOR_CYAN, COLOR_BLACK);
  init_pair(ColourPairs.a, COLOR_YELLOW, COLOR_BLUE);

}

  WINDOW* create_newwin(int height, int width, int starty, int startx, ColourPairs border, ColourPairs text, string title = "")
  {
    WINDOW* local_win;
    local_win = newwin(height, width, starty, startx);
    wattron(local_win, COLOR_PAIR(border));
    box(local_win, A_NORMAL , A_NORMAL);
    wattroff(local_win, COLOR_PAIR(border));
    wbkgd(local_win, COLOR_PAIR(text) | A_BOLD);
    if (title != "") {
      mvwprintw(local_win, 0,cast(int)((COLS/2)-(title.length/2)), "%s", title.toStringz);
      }
    wrefresh(local_win);                    // Show that box
    return local_win;
  }
