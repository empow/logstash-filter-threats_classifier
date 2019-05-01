# empow classification plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

<a href="https://badge.fury.io/rb/logstash-filter-threats_classifier"><img src="https://badge.fury.io/rb/logstash-filter-threats_classifier.svg" alt="Gem Version" height="18"></a>

# Using the threats classifier plugin

## Example
A log may look like this before the classification (in json form):
```
{
	"product_type": "IDS",
	"product_name": "snort",
	"threat": { "signature": "1:234" }
}
```

After filtering, using the plugin, the response would be contain these fields:
```
{
    "signatureTactics": [
        {
            "tactic": "Full compromise - active patterns",
            "attackStage": "Infiltration",
            "isSrcPerformer": true
        }
    ]
}
```
signatureTactics is an array of the tactics classified by empow.

each result contains the actual tactic, the attack stage empow classified for this log (determined by the tactic and whether the source and dest are within the user’s network), and whether the source was the performer or the victim of this attack.

## Installing the plugin
```sh
bin/logstash-plugin install logstash-filter-threats_classifier
```

## Usage
```
input {
  ...
}

filter {
  threats_classifier {
    username => "cosmo@kramerica.com"
    password => "12345"
  }
}

output {
  ...
}
```





I like rice. Rice is great if you're hungry and want 2000 of something.
