module ::Garnet::Interface::Logger

  def puts_info(_msg : String?)
    return unless msg = _msg
    puts light_gray(msg)
  end

  def puts_success(_msg : String?)
    return unless msg = _msg
    puts light_green(msg)
  end

  def puts_error(_msg : String?)
    return unless msg = _msg
    puts red(msg)
  end

  def puts_warning(_msg : String?)
    return unless msg = _msg
    puts yellow(msg)
  end

  def debug(msg : String)
    log_out("Debug", msg, :light_gray)
  end

  def error(msg : String)
    log_out("Error", msg, :red)
  end

  def warning(msg : String)
    log_out("Warning", msg, :yellow)
  end

  def info(msg : String)
    log_out("Info", msg, :light_green)
  end

  private def log_out(t : String, msg : String, color : Symbol)
    puts "[ #{ftime} -- #{tag(t, color)} ] #{msg}"
  end

  private def tag(t : String, color : Symbol) : String
    ("%7s" % t).colorize.fore(color).to_s
  end

  private def ftime : String
    Time.now.to_s("%Y-%m-%d %H:%M:%S")
  end

  include Common::Color
end