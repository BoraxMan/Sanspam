import std.exception;

class SpaminexException : Exception
{
private:
  string m_errortype;
  
public:
  
  this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @safe pure nothrow
  {
    super(msg, file, line, next);
  }

  string getErrorType() const @safe pure
  {
    return m_errortype;
  }
  
}
