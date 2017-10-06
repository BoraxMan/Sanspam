import std.exception;

class SpaminexException : Exception
{
private:
  string m_errortype;
  
public:
  
  this(string msg) @safe pure
  {
    super(msg);
  }

  this(string error_type, string msg) @safe pure
  {
    super(msg);
    m_errortype = error_type;
  }
  
  string getErrorType() const @safe pure
  {
    return m_errortype;
  }
  
}
