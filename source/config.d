/* A simple class to load a basic configuration file consisting of
   key = value lines with a [header].  The [header] entry indicates the beginning
   of a set of configuration values which relate to a single account.  [heading]
   forms the account title.

   Spaminex refers to the account as a 'mailbox'.
*/

import core.stdc.stdlib : getenv;
import spaminexexception;
import std.string;
import std.file;
import std.format;
import std.conv;
import std.stdio;
import std.typecons;
import std.uni : toLower;

immutable string separator = "=";
immutable string filename = "accounts.conf";

Config[string] configurations;
Config currentConfig;
string path;

void init()
{
  File file;

  path = getenv("HOME").to!string;
  path~="/.config/spaminex/";
  if(!exists(path)) {
    try {
    mkdirRecurse(path);
    } catch (FileException e) {
      throw new SpaminexException("Could not make configuration directory",e.msg);
    }
  }
  if(exists(path~filename)) {
    try {
    file.open(path~filename,"r");
    readConf(file);
    } catch (FileException e) {
      file.close;
      throw new SpaminexException("Could not read configuration file.","File "~filename~" : "~e.msg);
    }
  }
  file.close;
}

Config getConfig(in string configTitle) @safe
{
  if (configExists(configTitle)) {
    return configurations[configTitle];
  } else {
    throw new SpaminexException("Invalid configuration set", "Configuration set "~configTitle~" does not exist.");
  }
}

bool configExists(in string configTitle) @safe nothrow
{
  if(configTitle in configurations) {
    return true;
  } else {
    return false;
  }
}

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
    throw new SpaminexException("Open file error", tempFile~" "~e.msg);
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
    throw new SpaminexException("Write error", tempFile~" "~e.msg);
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
	writeln(item);
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

/*
  Old function, may not need this, but keeping it in case.

  void processLine(in char[] item) @safe
  {
  const auto values = item.split();
  if (values.length != 3)
  return;
  if (values[1] != separator)
  return;
  if (currentConfig is null) {
  throw new SpaminexException("Invalid configuration option",item.to!string);
  }
  
  currentConfig.modify(values[0].to!string.toLower, values[2].to!string);
  }
*/

void processLine(in char[] item)
{
  string key;
  string value;
  string text = item.to!string;

  try {
    text.formattedRead("%s = %s", &key, &value);
  } catch (Exception e) {
    writeln("Invalid configuration line", e.msg~"Offending string is : "~item);
    return;
  }
  if (currentConfig is null) {
    throw new SpaminexException("Configuration line doesn't belong to an account.",item.to!string);
  }
  currentConfig.modify(key.toLower, value);
}

class Config
{
private:
  string[string] m_configOption;
  string m_configTitle;

public:
  @property string title() const @safe nothrow pure
  {
    return m_configTitle;
  }
  
  this(in char[] title) @safe nothrow
  {
    m_configTitle = title.to!string;
  }
  
  void modify(string key, string value = "") @safe nothrow
  {
    /* If value is "", then delete.
       A key can be deleted by not specifiying a value. */
    
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
  bool hasSetting(in string key) const @safe nothrow pure
  {
    const string *p = (key in m_configOption);
    if (p !is null) {
      return true;
    } else {
      return false;
    }
  }

  string getSetting(in string key) const @safe pure
  {
    if(hasSetting(key)) {
      return m_configOption[key];
    } else {
      throw new SpaminexException("Setting doesn't exist", key);
    }
  }
 
}

unittest
{
  init;
  Config a = getConfig("test1");
  Config b = getConfig("test2");
  Config c = getConfig("netspace");
  assert (b.hasSetting("username") == false);
  writeln(a.getSetting("pop"));
  writeln(a.getSetting("quoted"));
  assert(configExists("test1") == true);
  assert(configExists("zzzzzzz") == false);
  writeln(b.getSetting("pop"));
  a.modify("test","value");


  writeConf();
}
