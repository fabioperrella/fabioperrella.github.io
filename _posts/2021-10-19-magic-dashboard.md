# Monitoring the performance of Ruby and Rails Applications with Magic Dashboards

## Types of dashboards

### Performance

Examples:
- response time: the time that an endpoint responds to a request
- process time: the time that a operation takes to be executed

We can use them to:
- show that a change improved something
- detect that something wrong is happenning with the application
- create SLIs

To add one, we can simply measure a time of an operation and add the result to a Distribution, for example:

```ruby
t1 = Time.now
# run_operation x
t2 = Time.now
delta_ms = (t2 - t1) * 1000
Appsignal.add_distribution_value("operation_x.total_time_ms", delta_ms)
```

### Throughput

Operations performed in specific amount of time.

Examples:
- Number of operations per seconds

We can use them to:
- Analyse if there is enough capacity to handle peak hours
- Identify possible culprits when the application is overloaded

To implement it, we can use a counter as follows:

```ruby
Appsignal.increment_counter("operation_x", 1)
```


## Important Metrics To Watch

### Error rate

### Throughput

### Response Time

## Create Different Dashboards For Each Region And Environment 

## ActionMailer

To show the volume and error rate of sent messages

## ActiveJob