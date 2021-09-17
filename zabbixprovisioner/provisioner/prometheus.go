package provisioner

import (
	"io/ioutil"
	"path/filepath"
	"strings"

	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	yaml "gopkg.in/yaml.v2"
)

type PrometheusAlertRules struct {
	Groups []struct {
		Rules []PrometheusRule `yaml:"rules"`
	} `yaml:"groups"`
}

type PrometheusRule struct {
	Name        string            `yaml:"alert"`
	Annotations map[string]string `yaml:"annotations"`
	Expression  string            `yaml:"expr"`
	Labels      map[string]string `yaml:"labels"`
}


func LoadPrometheusRulesFromDir(dir string) ([]PrometheusRule, error) {
	filesInDir, err := ioutil.ReadDir(dir)
	if err != nil {
		return nil, errors.Wrapf(err, "can't open the alerts files directory")
	}

	var rules []PrometheusRule

	for _, file := range filesInDir {
		if strings.HasSuffix(file.Name(), ".yml") || strings.HasSuffix(file.Name(), ".yaml") {
			alertsFile, err := ioutil.ReadFile(filepath.Join(dir, file.Name()))
			if err != nil {
				return nil, errors.Wrapf(err, "can't open the alerts file: %s", file.Name())
			}

			ruleConfig := PrometheusAlertRules{}

			err = yaml.Unmarshal(alertsFile, &ruleConfig)
			if err != nil {
				return nil, errors.Wrapf(err, "can't read the alerts file: %s", file.Name())
			}
			for _, rule := range ruleConfig.Groups {
				for _, alert := range rule.Rules {
					if alert.Name != "" {
						if alert.Labels["severity"] != "" {
							oldName := alert.Name
							alert.Name = alert.Name + "--" + alert.Labels["severity"]
						    log.Debugf("DEBUG: severity set, renaming %#v to %#v\n", oldName, alert.Name)
						} else {
							log.Debugf("DEBUG: severity NOT set, leaving name alone: %#v\n", alert.Name)
						}
						rules = append(rules, alert)
					}
				}
			}

		}
	}

	for i := 0; i < len(rules); i++ {
		for j := i + 1; j < len(rules); j++ {
			if rules[j].Name == rules[i].Name {
				// One approach would be to fail because this is nonsense:
				//return nil, errors.Errorf("can't load rules with the same alertname: %v, index: %v, %v", rules[j].Name, i+1, j+1)
				// Let's take the way more expensive, irritating, insane option:
				// ...reslice without one of these duplicate rules, then hope it all works out!
				log.Debugf("DEBUG: removing duplicate copy of %#v (...to avoid explosions, of course)\n", rules[i].Name)
				rules = append(rules[:i], rules[i+1:]...)
			}
		}
	}

	return rules, nil
}
