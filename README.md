# hubot-octopus

An Octopus Deploy adapter for Hubot

## Installation

Assuming that you've already installed hubot:

1. `npm install hubot-octopus --save`
2. Add `"hubot-octopus"` to your `external-scripts.json`

##Usage

This adapter currently supports the current hubot commands:

###Promote
```
kneumei > hubot octo promote Development from Test to QA
Promoted 2.5.202.5 from Test to QA
```

## Configuration

### OCTOPUS_URL_BASE
This environment variable is the base of your octopus installation. For example, `http://octopus.yourcompany.com`

### OCTOPUS_API_KEY
The octopus api key needed to call the octopus API

