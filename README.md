SANSPAM
===

Author
---
Dennis Katsonis

Introduction
---
Sanspam is an interactive tool to allow you to easily scan your e-mail Inbox and delete any messages you don't want.  In addition to this, you can bounce back an error message to the sender, which may dissuade spammers from reusing your e-mail address. Sanspam is inspired by Save My Modem by Enrico Tasso and SpamX by Emmanual Vasilakis, which are two simple, easy to set up tools that I used to use, but aren't maintained any more and require too much work to justify update.

This program is intended for simple, basic e-mail pruning.

Sanspam supports POP and IMAP accounts, and also supports SSL for secure connections.

This is more suited to those who use e-mail clients and prefer to download messages to their computer, but also prefer not to allow spam, or potentially harmful messages to be downloaded at all.  Instead of running a risk having it downloaded by the e-mail client, Sanspam allows you to delete it on the server, without being exposed to any attachments or e-mail content.

How to use
---
Sanspam reads its options from an INI style configuration file.  The configuration file lives in the .config/sanspam/ directory/folder in your home directory and is titled "accounts.conf".  Create a directory called "sanspam" in your ".config" folder and using your preferred text editor, create a file called "accounts.conf".  

Check the Configuration Options section below for configuration options.

When sanspam is started, it displays a list of configured e-mail accounts.  Selecting the account will then display a list of e-mails.  Use the arrows to navigate and and down the list and press "I" if you want further details on the e-mail.  While in the e-mail list, you can press D to mark the message for deletion or B to mark it for bounce and deletions.  Bounced messages will be sent back to the sender with a fake error, designed to possibly fool the sender into considering the e-mail address invalid and therefore not a suitable target for more spam.  An SMTP server must be configured to bounce messages.  It is recommended that the bounce option be used frugally.

Pressing Q will Quit, and delete all selected messages and bounce those marked for deletion.  Pressing C will cancel all operations and no e-mails will be deleted.

Configuration Options
---
Configuration is in configuration group, with each group pertaining to a specific e-mail account you have.  The account name is specified on its own line inbetween square brackets "[ & ]".  After this, list your options.  Options specific for the Sanspam program are listed under a section called [sanspam].  Obviously, you cannot call your own e-mail account configuration 'sanspam'.

Each option is on a separate line and follows the following format.

option = value.

Valid options for mail accounts are

* **username:** The username used to log into the mail server.
	
* **password:** The password used to log into the mail server.  Note that this is stored in plain text, so the configuration file should be kept secure.  If no password is supplied, Sanspam will prompt for one.  (optional).

* **pop:** The incoming pop server if using a POP account.
	
* **imap:** The incoming imap server of using an IMAP account.
	
* **smtp:** The outgoing SMTP server (optional).

* **port:** The port number of the incoming server.  Typically 110 for POP and 143 for IMAP, 993 for POP using SSL.
	
* **type:** imap or pop
	
* **smtp_port:** The port number of the SMTP server (optional).

* **smtp_authtype:** The type of SMTP authentication.  Options are "none" or "login".

	
An example is below...


[hotmail]  
smtp_port = 25  
port = 993  
type = imap  
password = ThePassword  
pop = pop.outlook.com  
imap = imap-mail.outlook.com  
username = JohnDoe@hotmail.com  


Valid options for sanspam are

* **colourscheme:** The colour scheme to use.  Options are "neon", "blue" and "white".  Default is "neon" which is light colours against a black background.

* **allowsmallterm:** By default, sanspam will report an error if the terminal is less than 80x25.
	But if you wish to use sanspam on smaller terminals, with difficulty, set this to
	"true".  Any other setting will be regared as "false".

* **messagedelay:** The duration for messages to appear at the status bar at the bottom, in milliseconds.  The default is 1000 milliseconds (1 second);

Development
---
This is partly written for personal use, and partly as a small project to begin learning the D Programming Language.  It is my first proper D program, though still somewhat written in an idiomatic C++ style instead of an idiomatic D style.

Licence
---
Copyright Dennis Katsonis, 2018

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Version
---
0.1.7
