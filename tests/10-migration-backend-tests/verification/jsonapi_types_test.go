package main

import (
	"fmt"
	"github.com/stretchr/testify/assert"
	"net/url"
	"strings"
)

// Encapsulates the relevant components of a URL which executes a JSON API request against Drupal
type JsonApiUrl struct {
	t            assert.TestingT
	baseUrl      string
	drupalEntity string
	drupalBundle string
	filter       string
	value        string
}

// Compose and return the JSONAPI URL
func (json *JsonApiUrl) String() string {
	var u *url.URL
	var err error

	assert.NotEmpty(json.t, json.baseUrl, "error generating a JsonAPI URL from %v: %s", json, "base url must not be empty")
	assert.NotEmpty(json.t, json.drupalEntity, "error generating a JsonAPI URL from %v: %s", json, "drupal entity must not be empty")
	assert.NotEmpty(json.t, json.drupalBundle, "error generating a JsonAPI URL from %v: %s", json, "drupal bundle must not be empty")

	u, err = url.Parse(fmt.Sprintf("%s", strings.Join([]string{DrupalBaseurl, "jsonapi", json.drupalEntity, json.drupalBundle}, "/")))
	assert.Nil(json.t, err, "error generating a JsonAPI URL from %v: %s", json, err)

	if json.filter != "" {
		u, err = url.Parse(fmt.Sprintf("%s?filter[%s]=%s", u.String(), json.filter, json.value))
	}

	assert.Nil(json.t, err, "error generating a JsonAPI URL from %v: %s", json, err)
	return u.String()
}

type JsonApiData struct {
	Type DrupalType
	Id   string
}

// Represents the results of a JSONAPI query for a single Person from the Person Taxonomy
type JsonApiPerson struct {
	JsonApiData []struct {
		Type              DrupalType
		Id                string
		JsonApiAttributes struct {
			Name        string
			Dates       []string `json:"field_date"`
			Description struct {
				Value     string
				Format    string
				Processed string
			}
			PreferredNameTitle        []string `json:"field_preferred_name_prefix"`
			PreferredNameGiven        []string `json:"field_preferred_name_rest"`
			PreferredNameFamily       string   `json:"field_primary_part_of_name"`
			PreferredNameGenerational []string `json:"field_preferred_name_suffix"`
			Authority                 []struct {
				Uri    string
				Title  string
				Source string
			} `json:"field_authority_link"`
		} `json:"attributes"`
		JsonApiRelationships struct {
			Relationships struct {
				Data []struct {
					JsonApiData
					Meta map[string]string
				}
			} `json:"field_relationships"`
		} `json:"relationships"`
	} `json:"data"`
}

// Represents the results of a JSONAPI query for a single repository object
type JsonApiRepoObj struct {
	JsonApiData []struct {
		Type              DrupalType
		Id                string
		JsonApiAttributes struct {
			Title       string
			Description string
			Extent      []string `json:"field_extent"`
		} `json:"attributes"`
		JsonApiRelationships struct {
			Model struct {
				Data JsonApiData
			} `json:"field_model"`
			MemberOf struct {
				Data []JsonApiData
			} `json:"field_member_of"`
			ResourceType struct {
				Data JsonApiData
			} `json:"field_resource_type"`
			LinkedAgent struct {
				Data []struct {
					JsonApiData
					Meta map[string]interface{}
				}
			} `json:"field_linked_agent"`
			DisplayHint struct {
				Data JsonApiData
			} `json:"field_display_hints"`
		} `json:"relationships"`
	} `json:"data"`
}
