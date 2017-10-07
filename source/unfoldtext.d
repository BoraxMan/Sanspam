module unfoldtext;
import conversion;
import std.string;

class UnfoldText
{
private:
  string m_UnfoldedText; // Final unfolded
  string[] m_textArray;

public:

  @property size_t length() const @safe
  {
    return m_textArray.length;
  }

  void addLine(in string text) @trusted
  {
    /* We need to decode before unfolding the text, because for Base64 encoded multi-lines
       in email headers, they are encoded separately. */
    m_textArray~=text.decodeText;
  }

  void clear() @safe
  {
    m_textArray.length = 0;
    m_UnfoldedText="";
  }

  string unfolded() @safe
  {
    scope(exit) clear;

    foreach(line; m_textArray) {
	string newstring = chomp(line);
	m_UnfoldedText~=newstring;
      }
    // Add end line back on.
    //m_UnfoldedText~="\r\n";
    return m_UnfoldedText;
  }
}

unittest
{
  UnfoldText u = new UnfoldText();
  string text2 = "A single line message.\r\n";
  
  string text31 = "A multline message on\r\n";
  string text32 = " multiple\r\n";
  string text33 = " lines.\r\n";

  u.addLine(text2);
  auto result2 = u.unfolded;
  assert(result2 == "A single line message.\r\n");
  u.clear;
  assert(u.length == 0);

  u.addLine(text31);
  u.addLine(text32);
  u.addLine(text33);
  auto result3 = u.unfolded;
  assert(result3 == "A multline message on multiple lines.\r\n");  
}


