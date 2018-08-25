import std.net.isemail;
import std.regex;
import deimos.ncurses;
import deimos.ncurses.menu;
import std.string;
import std.typecons;
import uidefs;
import message;

struct messageInspector
{
  const Message *m_message;
  immutable int titleColumn = 1;
  immutable int dataColumn = 14;
  int row;
  EmailStatus emailStatus;
  
  void printMessageInspectorItem(in string label, in string data)
  {
    int x;
    getyx(inspectorWindow, row, x);
    wmove(inspectorWindow, ++row, titleColumn);
    wattron(inspectorWindow, A_BOLD);
    wprintw(inspectorWindow, label.toStringz);
    wattroff(inspectorWindow, A_BOLD);
    wmove(inspectorWindow, row, dataColumn);
    wprintw(inspectorWindow, data.toStringz);
  }
  
  this(in Message *_message)
  {
    int y;
    int x;
    m_message = _message;
    string email;
    ptrdiff_t i = m_message.from.indexOfAny("<"); // This means the e-mail address is enclosed in brackets.
    // If so, extract e-mail address.

    if (i != -1)
      {
	auto result = matchFirst(m_message.from, regex(r"<.+>"));
	if (result.length == 0) {
	  // If the regex extraction failed, set back to the orginal and hope for the best
	  email = m_message.from;
	} else {
	  email = result.hit[1..$-1]; // 1..$-1 is to remove the parenthesis.
	}
      }
    
    emailStatus = isEmail(email);
    inspectorWindow = create_newwin(LINES-3,COLS-2,1,1,ColourPairs.AccountMenuFore, ColourPairs.AccountMenuBack,"Message Details", No.hasBox);

    wattron(inspectorWindow, COLOR_PAIR(ColourPairs.StandardText));
    printMessageInspectorItem("Subject : ", m_message.subject);
    printMessageInspectorItem("Date : ", m_message.date);
    printMessageInspectorItem("To : ", m_message.to);
    printMessageInspectorItem("From : ", m_message.from);

    wmove(inspectorWindow, ++row, dataColumn);
    if (emailStatus.valid == true) {
      wattron(inspectorWindow, COLOR_PAIR(ColourPairs.GreenText) | A_BOLD);
      wmove(inspectorWindow, row, dataColumn);
      wprintw(inspectorWindow, "Email address is valid.");
      wattroff(inspectorWindow, A_BOLD);
    } else {
      wattron(inspectorWindow, COLOR_PAIR(ColourPairs.RedText) | A_BOLD);
      wmove(inspectorWindow, row, titleColumn);
      wprintw(inspectorWindow, "Email address is not valid.");
      row++;
      wprintw(inspectorWindow, emailStatus.toString.toStringz);
      wattroff(inspectorWindow, A_BOLD);
    }
    wattron(inspectorWindow, COLOR_PAIR(ColourPairs.StandardText));

    printMessageInspectorItem("Return Path : ", m_message.returnPath);
    printMessageInspectorItem("Received : ", m_message.received);

 
    wrefresh(inspectorWindow);
    writeStatusMessage("Press any key to return.");
  }
  
  ~this()
  {
    touchwin(inspectorWindow);
    wgetch(inspectorWindow);
    wclear(inspectorWindow);
    wrefresh(inspectorWindow);
    delwin(inspectorWindow);
  }
}
