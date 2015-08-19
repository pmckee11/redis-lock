class ConnectionPool
  def initialize(decoree)
    @decoree = decoree
  end
  
  def with
    yield @decoree
  end
end
