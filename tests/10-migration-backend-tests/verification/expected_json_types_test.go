package main

import "strings"

// Encapsulates the entity type and bundle of a Drupal resource.
//
// DrupalType is parsed from the JSONAPI response, where type is represented, e.g. as:
//   "type": "taxonomy_term--person"
type DrupalType string

// The entity (e.g. taxonomy_term, node, etc) encapsulated by this type
func (t DrupalType) entity() string {
	return strings.Split(string(t), "--")[0]
}

// The bundle (e.g. 'person', 'islandora_object', etc) encapsulated by this type
func (t DrupalType) bundle() string {
	return strings.Split(string(t), "--")[1]
}

// Represents the expected results of a migrated person
type ExpectedPerson struct {
	Type          string
	Bundle        string
	Title         string
	FirstName     string `json:"first_name"`
	MiddleName    string `json:"middle_name"`
	LastName      string `json:"last_name"`
	Suffix        string
	Number        string
	AltTitle      string `json:"alt_title"`
	AltFirstName  string `json:"alt_first_name"`
	AltMiddleName string `json:"alt_middle_name"`
	AltLastName   string `json:"alt_last_name"`
	AltSuffix     string `json:"alt_suffix"`
	AltNumber     string `json:"alt_number"`
	Born          string
	Died          string
	Knows         []string
	Authority     []struct {
		Uri  string
		Name string
		Type string
	}
	Description struct {
		Value     string
		Format    string
		Processed string
	}
}

// Represents the expected results of a migrated repository object
type ExpectedRepoObj struct {
	Type         string
	Bundle       string
	Model        string
	ResourceType string `json:"resource_type"`
	Title        string
	MemberOf     string `json:"member_of"`
	Extent       []string
	LinkedAgent  []struct {
		Rel  string
		Name string
	}
	DisplayHint string `json:"display_hint"`
	Description string
}

// Represents the expected results of a migrated Access Rights taxonomy term
type ExpectedAccessRights struct {
	Type      string
	Bundle    string
	Name      string
	Authority []struct {
		Uri    string
		Title  string
		Source string
	}
	Description struct {
		Value     string
		Format    string
		Processed string
	}
}

// Represents the expected results of a migrated Copyright and Use taxonomy term
type ExpectedCopyrightAndUse struct {
	Type      string
	Bundle    string
	Name      string
	Authority []struct {
		Uri    string
		Title  string
		Source string
	}
	Description struct {
		Value     string
		Format    string
		Processed string
	}
}

// Represents the expected results of a migrated Family taxonomy term
type ExpectedFamily struct {
	Type       string
	Bundle     string
	Name       string
	Date       []string
	FamilyName string `json:"family_name"`
	Title      string
	Authority  []struct {
		Uri    string
		Title  string
		Source string
	}
	Description struct {
		Value     string
		Format    string
		Processed string
	}
	KnowsAbout []string `json:"knowsAbout"`
}
