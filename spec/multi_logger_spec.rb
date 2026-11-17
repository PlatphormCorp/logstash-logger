require 'logstash-logger'

describe LogStashLogger::MultiLogger do
  include_context 'device'

  # Create a MultiLogger writing to both STDOUT and a StringIO
  subject { multi_logger }

  it { is_expected.to be_a LogStashLogger::MultiLogger }

  it "has multiple loggers" do
    expect(subject.loggers.count).to eq(2)
  end

  it "has one logger per output" do
    expect(subject.loggers[0].device).to be_a LogStashLogger::Device::Stdout
    expect(subject.loggers[1].device).to be_a LogStashLogger::Device::IO
  end

  it "allows a different formatter for each logger" do
    expect(subject.loggers[0].formatter.class).to eq ::Logger::Formatter
    expect(subject.loggers[1].formatter.class).to eq LogStashLogger::Formatter::JsonLines
  end

  it "logs to all loggers" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:info).with("test")
    end

    subject.info("test")
  end

  it "supports silenced logging" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:silence).and_call_original
      expect(logger.device).to receive(:write).once
    end

    subject.silence(::Logger::WARN) do |logger|
      expect(logger).to eq(subject)
      logger.info 'info'
      logger.warn 'warning'
    end
  end

  it "supports tagged logging" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:tagged).with('tag').and_call_original
      expect(logger.device).to receive(:write) do |event_string|
        event = JSON.parse(event_string)
        expect(event['tags']).to match_array(['tag'])
      end
    end

    subject.tagged('tag') do |logger|
      logger.info 'test'
    end
  end

  it "puts pushed tags on every logger's events until they are popped" do
    first_io = StringIO.new
    second_io = StringIO.new
    logger = LogStashLogger.new(type: :multi_logger, outputs: [{ type: :io, io: first_io }, { type: :io, io: second_io }])

    pushed_count = logger.push_tags('tag').size
    logger.info('tagged')
    logger.pop_tags(pushed_count)
    logger.info('untagged')

    [first_io, second_io].each do |io|
      events = io.string.lines.map { |line| JSON.parse(line) }
      expect(events.map { |event| event['tags'] }).to eq([['tag'], nil])
    end
  end

  it "exposes the current tags" do
    logger = LogStashLogger.new(type: :multi_logger, outputs: [{ type: :io, io: StringIO.new }, { type: :io, io: StringIO.new }])

    pushed_count = logger.push_tags('tag').size
    current_tags = logger.current_tags
    logger.pop_tags(pushed_count)

    expect(current_tags).to eq(['tag'])
  end
end
