package main

import (
	"strings"
)

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

// Represents the expected results of a migrated Genre taxonomy term
type ExpectedGenre struct {
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

// Represents the expected results of a migrated Geolocation taxonomy term
type ExpectedGeolocation struct {
	Type       string
	Bundle     string
	Name       string
	GeoAltName []string `json:"geo_alt_name"`
	Broader    []struct {
		Uri   string
		Title string
	}
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

// Represents the expected results of a migrated Resource Types taxonomy term
type ExpectedResourceType struct {
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

// Represents the expected results of a migrated Subject taxonomy term
type ExpectedSubject struct {
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

// Represents the expected results of a migrated Language taxonomy term
type ExpectedLanguage struct {
	Type         string
	Bundle       string
	Name         string
	LanguageCode string `json:"language_code"`
	Authority    []struct {
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

// Represents the expected results of a migrated Collection entity
type ExpectedCollection struct {
	Type          string
	Bundle        string
	Title         string
	TitleLangCode string `json:"title_language"`
	AltTitle      []struct {
		Value    string
		LangCode string `json:"language"`
	} `json:"alternative_title"`
	Description []struct {
		Value    string
		LangCode string `json:"language"`
	}
	ContactEmail     string   `json:"contact_email"`
	ContactName      string   `json:"contact_name"`
	CollectionNumber []string `json:"collection_number"`
	MemberOf         []string `json:"member_of"`
	FindingAid       []struct {
		Uri   string
		Title string
	}
}

// Represents the expected results of a migrated Corporate Body taxonomy term
type ExpectedCorporateBody struct {
	Type        string
	Bundle      string
	Name        string
	Description struct {
		Value     string
		Format    string
		Processed string
	}
	PrimaryName        string `json:"primary_name"`
	SubordinateName    string `json:"subordinate_name"`
	DateOfMeeting      string `json:"date_of_meeting_or_treaty"`
	Location           string `json:"location_of_meeting"`
	NumberOrSection    string `json:"num_of_section_or_meet"`
	AltDate            string `json:"alt_date_of_meeting"`
	AltLocation        string `json:"alt_location_of_meeting"`
	AltNumberOrSection string `json:"alt_number_of_section_or_meeting"`
	AltPrimaryName     string `json:"alt_primary_name"`
	AltSubordinateName string `json:"alt_subordinate_name"`
	Authority          []struct {
		Uri    string
		Title  string
		Source string
	}
	Date         []string
	Relationship []struct {
		Name string
		Rel  string `json:"rel_type"`
	} `json:"relationships"`
}
