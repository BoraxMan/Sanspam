import std.exception;
import std.stdio;
import spaminexexception;

class ExceptionHandler
{
private:
  SpaminexException m_exception;

public:
  this(SpaminexException e) @safe
  {
    m_exception = e;
  }

  void display() @safe const
  {
    writeln(m_exception.getErrorType());
    writeln(m_exception.msg);
  }
  
}
