require 'logstash-logger'

describe LogStashLogger do
  include_context 'logger'

  describe "tagged logging" do
    let(:message) { 'foo' }
    let(:tag) { 'bar' }

    it "puts tags into the tags array on the logstash event" do
      expect(logdev).to receive(:write) do |event_string|
        event = JSON.parse(event_string)
        expect(event['tags']).to match_array([tag])
        expect(event['message']).to eq(message)
      end

      logger.tagged(tag) do
        logger.info(message)
      end
    end

    it "doesn't put tags on the event when there are no tags" do
      expect(logdev).to receive(:write) do |event_string|
        event = JSON.parse(event_string)
        expect(event['tags']).to be_nil
        expect(event['message']).to eq(message)
      end

      logger.info(message)
    end

    it "puts pushed tags on events until they are popped" do
      io = StringIO.new
      logger = LogStashLogger.new(type: :io, io: io)

      logger.push_tags('bar', 'baz')
      logger.info('tagged')
      logger.pop_tags(2)
      logger.info('untagged')

      events = io.string.lines.map { |line| JSON.parse(line) }
      expect(events.map { |event| event['tags'] }).to eq([%w[bar baz], nil])
    end

    it "exposes the current tags" do
      logger = LogStashLogger.new(type: :io, io: StringIO.new)

      logger.push_tags('bar')
      current_tags = logger.current_tags.dup
      logger.pop_tags

      expect(current_tags).to eq(['bar'])
    end
  end
end
