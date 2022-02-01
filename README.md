# Regulated Professions Data

Data transformation tools for [Regulated Professions Register](https://github.com/UKGovernmentBEIS/regulated-professions-register).

## Prerequisites

* Ruby 2.7.2
* CSV data in the format specified in `data/*.example.csv`

## Getting Started

```
#=> bundle install
#=> bundle exec ruby processor.rb
```

The JSON files will be available in `out/*.json`, and they
can then be added to the `seeds` directory in the Professions
Register project.


