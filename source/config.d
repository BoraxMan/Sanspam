// Written in the D Programming language.
/**
 * Authors: Dennis Katsonis
 */
/*
 * Sanspam: Mailbox utility to delete/bounce spam on server interactively.
 * Copyright (C) 2018  Dennis Katsonis dennisk@netspace.net.au
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

/*** A simple class to load a basic configuration file consisting of
 *  key = value lines with a [header].  The [header] entry indicates the beginning
 *  of a set of configuration values which relate to a single account.  [heading]
 *  forms the account title.
 *
 * Each Configuraiton object forms a configuration 'set'.
 *
 *  Sanspam refers to the account as a 'mailbox'.
 *
*/

import core.stdc.stdlib : getenv;
import sanspamexception;
import std.string;
import std.file;
import std.format;
import std.conv;
import std.stdio;
import std.typecons;
import std.uni : toLower;

string separator = "=";
string filename = "accounts.conf";

Config[string] configurations;
Config currentConfig;
string path;

static this()
{
  File file;

  path = getenv("HOME").to!string;
  path~="/.config/sanspam/";
  if(!exists(path)) {
    try {
    mkdirRecurse(path);
    } catch (FileException e) {
      throw new SanspamException("Could not make configuration directory",e.msg);
    }
  }
  if(exists(path~filename)) {
    try {
    file.open(path~filename,"r");
    readConf(file);
    } catch (FileException e) {
      file.close;
      throw new SanspamException("Could not read configuration file.","File "~filename~" : "~e.msg);
    }
  }
  file.close;
}

/***********
 * getConfig returns a Configuration set matching the string configtitle.
 * The Config object will contain name/value pairs containing the 
 * configuration options for that object.
 * 
 * Typically, each object will be a mailbox.  Object 'sanspam' is reserved
 * for global sanspam program options.
 */

Config getConfig(in string configTitle) @safe
{
  if (configExists(configTitle)) {
    return configurations[configTitle];
  } else {
    throw new SanspamException("Invalid configuration set", "Configuration set "~configTitle~" does not exist.");
  }
}

/// Returns 'true' if a Configuration set
bool configExists(in string configTitle) @safe nothrow
{
  if(configTitle in configurations) {
    return true;
  } else {
    return false;
  }
}

/*******
 * Writes all loaded Configurations to the default
 * configuraiton file.
 */
size_t writeConf() @safe
{
  // Returns the number of configuration objects written.
  immutable string tempFile = filename~".bak";
  if (configurations.length == 0) {
    return 0;
  }
  File file;
  try {
    file.open(path~tempFile,"w");
  } catch (FileException e) {
    throw new SanspamException("Open file error", tempFile~" "~e.msg);
  }

  try {
    foreach(k, v; configurations) {
      file.writeln("["~k~"]");
      foreach(ck,cv; v.m_configOption) {
	file.writeln(ck," "~separator~" "~cv);
      }
      file.writeln;
    }
    file.close;
  } catch (FileException e) {
    throw new SanspamException("Write error", tempFile~" "~e.msg);
  } 
  remove(path~filename);
  rename(path~tempFile, path~filename);
  return configurations.length;
}


size_t readConf(ref File file)
{
  try {
    auto range = file.byLine();
    foreach(item; range) {
      if (item.startsWith("#") || (item.length == 0)) {
	// Is a comment or blank line, ignore.
	continue;
      } else if (item.startsWith("[") && item.endsWith("]")) {
	if(currentConfig !is null) {
	  configurations[currentConfig.title]=currentConfig;
	}
	item = item.chomp("]");
	item = item.chompPrefix("[");
	currentConfig = new Config(item);
      } else {
	processLine(item);
      }
    }
  } catch (Exception e) {
    
  }
  if (currentConfig !is null) {
    configurations[currentConfig.title]=currentConfig;
  }
  return configurations.length;
}


/*******
 * This reads a line of text, and add the option to 
 * 'currentConfig'.  This function is used internally by config.d
 * for setting up all the configuration objects.
 *
 */
void processLine(in char[] item)
{
  string key;
  string value;

  try {
    item.to!string.formattedRead("%s = %s", &key, &value);
  } catch (Exception e) {
    throw new SanspamException("Invalid configuration line",e.msg~"Offending string is : "~item.to!string);
  }
  if (currentConfig is null) {
    throw new SanspamException("Configuration line doesn't belong to an account.",item.to!string);
  }
  currentConfig.modify(key.toLower, value);
}
/****
 * Class containing configuration objects.
 *
 * Configuration values and options are stored as 'strings'.  The configuration
 * option title forms the key.
 */


class Config
{
private:
  string[string] m_configOption;
  string m_configTitle;

public:
  /// The configuration object title.
  final @property string title() const @safe nothrow pure
  {
    return m_configTitle;
  }
  
  final this(in char[] title) @safe nothrow
  {
    m_configTitle = title.to!string;
  }

  /// Return true if the configuration object has no configuraiton values in it.
  final bool empty() @safe pure nothrow
  {
    return (m_configOption.length == 0);
  }

  /******
   * Modify configuration option "key" to have value "value".
   * If value is "", then delete.
   * A key can be deleted by setting the value to an empty string. */
  
  final void modify(string key, string value = "") @safe nothrow
  {
    
    if (value.length == 0) {
      if (key in m_configOption) {
	m_configOption.remove(key);
      } else {
	return;
      }
    } else {
      m_configOption[key] = value;
    }
  }

  /****
   * Returns 'true' if configuration option 'key' is present.
   */
  final bool hasSetting(in string key) const @safe nothrow pure
  {
    const string *p = (key in m_configOption);
    if (p !is null) {
      return true;
    } else {
      return false;
    }
  }

  /****
   * Returns the value of configuraiton option 'key'.
   * 
   * Throws an exception if 'key' does not exist.
   */
  
  final string getSetting(in string key) const @safe
  {
    if(hasSetting(key)) {
      return m_configOption[key];
    } else {
      throw new SanspamException("Setting doesn't exist", "Missing setting is \""~key~"\"");
    }
  }
 
}

unittest
{


}
