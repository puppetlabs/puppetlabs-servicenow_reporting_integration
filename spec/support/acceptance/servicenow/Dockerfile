# Unfortunately, building from 2.5 leads to https://github.com/debauchee/barrier/issues/126
# which means that we can't curl our mock instance. Thus, we build this from 2.5-alpine
# instead.
FROM ruby:2.7-alpine

WORKDIR .

ADD Gemfile ./
RUN bundle install --without development test

ADD mock_instance.rb ./

EXPOSE 8000

CMD ["bundle", "exec", "ruby", "./mock_instance.rb"]
