package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"testing"
)

const (
	// The name of the directory under 'tests/' that contains all the resources (test source code, migration csv, expected test results).
	// If this directory is renamed or moved, this constant must be updated.  See also `findExpectedJson(...)` and its
	// assumptions of the directory structure that are underneath the TestBaseDir.
	// TODO: consult env?
	TestBasedir = "10-migration-backend-tests"

	// The base URL of the test instance of IDC.
	// TODO: consult env
	DrupalBaseurl = "https://islandora-idc.traefik.me"
)

// Verifies that the Person migrated by testcafe persons-01.csv and persons-02.csv
// match the expected fields and values present in taxonomy-person-01.json
func Test_VerifyTaxonomyTermPerson_Person1(t *testing.T) {
	verifyTaxonomyTermPerson(t, "taxonomy-person-01.json", "Ansel Easton")
}

// Verifies that the Person migrated by testcafe persons-01.csv and persons-02.csv
// match the expected fields and values present in taxonomy-person-01.json
func Test_VerifyTaxonomyTermPerson_Person2(t *testing.T) {
	verifyTaxonomyTermPerson(t, "taxonomy-person-02.json", "Lewis Wickes")
}

func verifyTaxonomyTermPerson(t *testing.T, fileName string, restOfName string) {
	expectedJson := ExpectedPerson{}
	log.Printf("Test Person file: %s and %s", fileName, restOfName)
	unmarshalJson(t, fileName, &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "person", expectedJson.Bundle)
	assert.Equal(t, restOfName, expectedJson.RestOfName[0])
	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	personRes := &JsonApiPerson{}
	u.get(personRes)

	// for each field in expected json,
	//   see if the expected field matches the actual field from retrieved json
	//   resolve relationships if required
	//     - required for schema:knows
	actual := personRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.PrimaryName, actual.JsonApiAttributes.PrimaryPartOfName)
	assert.ElementsMatch(t, expectedJson.RestOfName, actual.JsonApiAttributes.PreferredNameRest)
	assert.ElementsMatch(t, expectedJson.Prefix, actual.JsonApiAttributes.PreferredNamePrefix)
	assert.ElementsMatch(t, expectedJson.Suffix, actual.JsonApiAttributes.PreferredNameSuffix)
	assert.ElementsMatch(t, expectedJson.Number, actual.JsonApiAttributes.PreferredNameNumber)
	assert.ElementsMatch(t, expectedJson.AltName, actual.JsonApiAttributes.PersonAlternateName)
	assert.ElementsMatch(t, expectedJson.Date, actual.JsonApiAttributes.Dates)
	assert.Equal(t, expectedJson.Authority[0].Uri, actual.JsonApiAttributes.Authority[0].Uri)
	assert.Equal(t, expectedJson.Authority[0].Type, actual.JsonApiAttributes.Authority[0].Source)
	assert.True(t, len(actual.JsonApiAttributes.Description.Processed) > 0)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.True(t, len(actual.JsonApiAttributes.Description.Value) > 0)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)

	// Resolve relationship to a name
	assert.Equal(t, 1, len(actual.JsonApiRelationships.Relationships.Data))
	relData := actual.JsonApiRelationships.Relationships.Data[0]
	assert.Equal(t, "schema:knows", relData.Meta["rel_type"])
	u.value = expectedJson.Knows[0]

	// retrieve json of the resolved entity from the jsonapi
	personRes = &JsonApiPerson{}
	u.get(personRes)
	relSchemaKnows := personRes.JsonApiData[0]

	// sanity
	assert.Equal(t, relSchemaKnows.Type.bundle(), "person")
	assert.Equal(t, relSchemaKnows.Type.entity(), "taxonomy_term")

	// test
	assert.Equal(t, expectedJson.Knows[0], relSchemaKnows.JsonApiAttributes.Name)
}

func Test_VerifyTaxonomyTermAccessRights(t *testing.T) {
	expectedJson := ExpectedAccessRights{}
	unmarshalJson(t, "taxonomy-accessrights.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "access_rights", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	accessRightsRes := &JsonApiAccessRights{}
	u.get(accessRightsRes)

	actual := accessRightsRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
}

func Test_VerifyTaxonomyCopyrightAndUse(t *testing.T) {
	expectedJson := ExpectedCopyrightAndUse{}
	unmarshalJson(t, "taxonomy-copyrightanduse.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "copyright_and_use", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	copyrightRes := &JsonApiCopyrightAndUse{}
	u.get(copyrightRes)

	actual := copyrightRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
}

func Test_VerifyTaxonomyTermFamily(t *testing.T) {
	expectedJson := ExpectedFamily{}
	unmarshalJson(t, "taxonomy-family-01.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "family", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	familyres := &JsonApiFamily{}
	u.get(familyres)
	sourceId := familyres.JsonApiData[0].Id
	assert.NotEmpty(t, sourceId)

	actual := familyres.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
	assert.Equal(t, expectedJson.Title, actual.JsonApiAttributes.Title)
	assert.Equal(t, expectedJson.FamilyName, actual.JsonApiAttributes.FamilyName)
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Date))
	assert.Equal(t, 2, len(expectedJson.Date))
	for i, v := range actual.JsonApiAttributes.Date {
		assert.Equal(t, expectedJson.Date[i], v)
	}

	// Resolve relationship to a name
	relData := familyres.JsonApiData[0].JsonApiRelationships.Relationships.Data[0]
	assert.Equal(t, "schema:knowsAbout", relData.Meta["rel_type"])
	u.value = expectedJson.KnowsAbout[0]

	// retrieve json of the resolved entity from the jsonapi
	familyres = &JsonApiFamily{}
	u.get(familyres)
	relSchemaKnowsAbout := familyres.JsonApiData[0]

	// sanity
	assert.Equal(t, relSchemaKnowsAbout.Type.bundle(), "family")
	assert.Equal(t, relSchemaKnowsAbout.Type.entity(), "taxonomy_term")

	// test
	assert.Equal(t, expectedJson.KnowsAbout[0], relSchemaKnowsAbout.JsonApiAttributes.Name)

	// assert the reciprocal relationship holds (e.g. the id referenced by the target is the same as the source id)
	assert.Equal(t, sourceId, relSchemaKnowsAbout.JsonApiRelationships.Relationships.Data[0].Id)
}

func Test_VerifyTaxonomyTermGenre(t *testing.T) {
	expectedJson := ExpectedGenre{}
	unmarshalJson(t, "taxonomy-genre.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "genre", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	genreRes := &JsonApiGenre{}
	u.get(genreRes)

	actual := genreRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
}

func Test_VerifyTaxonomyTermGeolocation(t *testing.T) {
	expectedJson := ExpectedGeolocation{}
	unmarshalJson(t, "taxonomy-geolocation.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "geo_location", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &JsonApiGeolocation{}
	u.get(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
	assert.Equal(t, 2, len(actual.JsonApiAttributes.GeoAltName))
	for i, v := range actual.JsonApiAttributes.GeoAltName {
		assert.Equal(t, expectedJson.GeoAltName[i], v)
	}
	assert.Equal(t, 0, len(actual.JsonApiAttributes.Broader))
	for i, v := range actual.JsonApiAttributes.Broader {
		assert.Equal(t, expectedJson.Broader[i].Title, v.Title)
		assert.Equal(t, expectedJson.Broader[i].Uri, v.Uri)
	}
}

func Test_VerifyTaxonomyTermResourceType(t *testing.T) {
	expectedJson := ExpectedAccessRights{}
	unmarshalJson(t, "taxonomy-resourcetypes.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "resource_types", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &JsonApiResourceType{}
	u.get(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
}

func Test_VerifyTaxonomySubject(t *testing.T) {
	expectedJson := ExpectedSubject{}
	unmarshalJson(t, "taxonomy-subject.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "subject", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &JsonApiSubject{}
	u.get(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
}

func Test_VerifyTaxonomyTermLanguage(t *testing.T) {
	expectedJson := ExpectedLanguage{}
	unmarshalJson(t, "taxonomy-language.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "language", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &JsonApiLanguage{}
	u.get(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
	assert.Equal(t, expectedJson.LanguageCode, actual.JsonApiAttributes.LanguageCode)
}

func Test_VerifyTaxonomyTermCorporateBody(t *testing.T) {
	expectedJson := ExpectedCorporateBody{}
	unmarshalJson(t, "taxonomy-corporatebody-02.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "corporate_body", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "name",
		value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &JsonApiCorporateBody{}
	u.get(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)
	assert.Equal(t, len(expectedJson.Authority), len(actual.JsonApiAttributes.Authority))
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Authority))
	for i, v := range actual.JsonApiAttributes.Authority {
		assert.Equal(t, expectedJson.Authority[i].Source, v.Source)
		assert.Equal(t, expectedJson.Authority[i].Uri, v.Uri)
	}
	assert.Equal(t, expectedJson.PrimaryName, actual.JsonApiAttributes.PrimaryName)
	assert.ElementsMatch(t, expectedJson.DateOfMeeting, actual.JsonApiAttributes.DateOfMeeting)
	assert.ElementsMatch(t, expectedJson.Location, actual.JsonApiAttributes.Location)
	assert.ElementsMatch(t, expectedJson.NumberOrSection, actual.JsonApiAttributes.NumberOrSection)
	assert.ElementsMatch(t, expectedJson.SubordinateName, actual.JsonApiAttributes.SubordinateName)
	assert.ElementsMatch(t, expectedJson.AltName, actual.JsonApiAttributes.AltName)
	assert.ElementsMatch(t, expectedJson.Date, actual.JsonApiAttributes.Date)

	// resolve and verify relationships

	// "My Corporate Body" -> 'schema:parentOrganization' -> "Parent Organization"
	relData := actual.JsonApiRelationships.Relationships.Data
	assert.Equal(t, 1, len(relData))
	assert.Equal(t, len(expectedJson.Relationship), len(relData))
	assert.Equal(t, "taxonomy_term", relData[0].Type.entity())
	assert.Equal(t, "corporate_body", relData[0].Type.bundle())
	assert.Equal(t, expectedJson.Relationship[0].Rel, relData[0].Meta["rel_type"])
	u = &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: relData[0].Type.entity(),
		drupalBundle: relData[0].Type.bundle(),
		filter:       "id",
		value:        relData[0].Id,
	}
	target := &JsonApiCorporateBody{}
	u.get(target)
	assert.Equal(t, expectedJson.Relationship[0].Name, target.JsonApiData[0].JsonApiAttributes.Name)

	//  "Parent Organization" -> 'schema:subOrganization' -> "My Corporate Body"
	assert.Equal(t, target.JsonApiData[0].JsonApiRelationships.Relationships.Data[0].Id, actual.Id)
	assert.Equal(t, target.JsonApiData[0].JsonApiRelationships.Relationships.Data[0].Meta["rel_type"], "schema:subOrganization")
}

func Test_VerifyCollection(t *testing.T) {
	expectedJson := ExpectedCollection{}
	unmarshalJson(t, "collection-01.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "node", expectedJson.Type)
	assert.Equal(t, "collection_object", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "title",
		value:        expectedJson.Title,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &JsonApiCollection{}
	u.get(res)
	sourceId := res.JsonApiData[0].Id
	assert.NotEmpty(t, sourceId)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.bundle())
	assert.Equal(t, expectedJson.Title, actual.JsonApiAttributes.Title)
	assert.Equal(t, expectedJson.ContactEmail, actual.JsonApiAttributes.ContactEmail)
	assert.Equal(t, expectedJson.ContactName, actual.JsonApiAttributes.ContactName)
	assert.ElementsMatch(t, expectedJson.CollectionNumber, actual.JsonApiAttributes.CollectionNumber)

	relData := res.JsonApiData[0].JsonApiRelationships

	// Resolve and verify title language
	assert.NotNil(t, relData.TitleLanguage.Data)
	assert.Equal(t, "taxonomy_term", relData.TitleLanguage.Data.Type.entity())
	assert.Equal(t, "language", relData.TitleLanguage.Data.Type.bundle())
	assert.Equal(t, expectedJson.TitleLangCode, relData.TitleLanguage.Data.langCode(t))

	// Resolve and verify alternate title values and languages
	assert.NotNil(t, relData.AltTitle.Data)
	assert.Equal(t, 2, len(relData.AltTitle.Data))
	assert.Equal(t, len(expectedJson.AltTitle), len(relData.AltTitle.Data))
	for i, altTitleData := range relData.AltTitle.Data {
		assert.Equal(t, "taxonomy_term", altTitleData.Type.entity())
		assert.Equal(t, "language", altTitleData.Type.bundle())
		assert.Equal(t, expectedJson.AltTitle[i].Value, altTitleData.value())
		assert.Equal(t, expectedJson.AltTitle[i].LangCode, altTitleData.langCode(t))
	}

	// Resolve and verify description values and languages
	assert.NotNil(t, relData.Description)
	assert.Equal(t, 2, len(relData.Description.Data))
	assert.Equal(t, len(expectedJson.Description), len(relData.Description.Data))
	for i, descData := range relData.Description.Data {
		assert.Equal(t, "taxonomy_term", descData.Type.entity())
		assert.Equal(t, "language", descData.Type.bundle())
		assert.Equal(t, expectedJson.Description[i].Value, descData.value())
		assert.Equal(t, expectedJson.Description[i].LangCode, descData.langCode(t))
	}

	// Resolve and verify member_of values
	assert.NotNil(t, relData.MemberOf)
	assert.Equal(t, 1, len(relData.MemberOf.Data))
	assert.Equal(t, len(expectedJson.MemberOf), len(relData.MemberOf.Data))
	for i, memberOfData := range relData.MemberOf.Data {
		assert.Equal(t, "node", memberOfData.Type.entity())
		assert.Equal(t, "collection_object", memberOfData.Type.bundle())

		u = &JsonApiUrl{
			t:            t,
			baseUrl:      DrupalBaseurl,
			drupalEntity: memberOfData.Type.entity(),
			drupalBundle: memberOfData.Type.bundle(),
			filter:       "id",
			value:        memberOfData.Id,
		}
		memberCol := JsonApiCollection{}
		u.get(&memberCol)

		assert.Equal(t, expectedJson.MemberOf[i], memberCol.JsonApiData[0].JsonApiAttributes.Title)

	}
}

func Test_VerifyRepositoryItem(t *testing.T) {
	expectedJson := ExpectedRepoObj{}
	unmarshalJson(t, "item-01.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "node", expectedJson.Type)
	assert.Equal(t, "islandora_object", expectedJson.Bundle)

	u := &JsonApiUrl{
		t:            t,
		baseUrl:      DrupalBaseurl,
		drupalEntity: expectedJson.Type,
		drupalBundle: expectedJson.Bundle,
		filter:       "title",
		value:        expectedJson.Title,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &JsonApiIslandoraObj{}
	u.get(res)
	actual := res.JsonApiData[0]
	sourceId := actual.Id
	assert.NotEmpty(t, sourceId)

	// Verify attributes
	attributes := actual.JsonApiAttributes

	// Title
	assert.Equal(t, expectedJson.Title, attributes.Title)

	// Collection Number
	assert.Equal(t, 2, len(expectedJson.CollectionNumber))
	assert.Equal(t, len(expectedJson.CollectionNumber), len(attributes.CollectionNumber))
	for i := range attributes.CollectionNumber {
		assert.Equal(t, expectedJson.CollectionNumber[i], attributes.CollectionNumber[i])
	}

	// Dates
	assert.Equal(t, expectedJson.DateAvailable, attributes.DateAvailable)
	assert.Equal(t, 2, len(expectedJson.DateCopyrighted))
	assert.Equal(t, len(expectedJson.DateCopyrighted), len(attributes.DateCopyrighted))
	for i := range attributes.DateCopyrighted {
		assert.Equal(t, expectedJson.DateCopyrighted[i], attributes.DateCopyrighted[i])
	}
	assert.Equal(t, 2, len(expectedJson.DateCreated))
	assert.Equal(t, len(expectedJson.DateCreated), len(attributes.DateCreated))
	for i := range attributes.DateCreated {
		assert.Equal(t, expectedJson.DateCreated[i], attributes.DateCreated[i])
	}
	assert.Equal(t, 2, len(expectedJson.DatePublished))
	assert.Equal(t, len(expectedJson.DatePublished), len(attributes.DatePublished))
	for i := range attributes.DatePublished {
		assert.Equal(t, expectedJson.DatePublished[i], attributes.DatePublished[i])
	}

	// Identifiers
	assert.Equal(t, 2, len(expectedJson.DigitalIdentifier))
	assert.EqualValues(t, expectedJson.DigitalIdentifier, attributes.DigitalIdentifier)
	assert.Equal(t, expectedJson.DspaceIdentifier, attributes.DspaceIdentifier.Uri)
	assert.Equal(t, expectedJson.DspaceItemId, attributes.DspaceItemid)

	// Library Catalog Link
	assert.Equal(t, expectedJson.LibraryCatalogLink, attributes.LibraryCatalogLink.Uri)

	// Extent
	assert.Equal(t, expectedJson.Extent, attributes.Extent)

	// Finding Aid
	assert.Equal(t, expectedJson.FindingAid, attributes.FindingAid.Uri)

	// Geoportal Link
	assert.Equal(t, expectedJson.GeoportalLink, attributes.GeoportalLink.Uri)

	// Issn
	assert.Equal(t, expectedJson.Issn, attributes.Issn)

	// Is Part Of
	assert.Equal(t, expectedJson.IsPartOf, attributes.IsPartOf.Uri)

	// Item Barcode
	assert.Equal(t, expectedJson.ItemBarcode, attributes.ItemBarcode)

	// JHIR
	assert.Equal(t, expectedJson.JhirUri, attributes.JhirUri.Uri)

	// OCLC
	assert.Equal(t, 2, len(expectedJson.OclcNumber))
	assert.EqualValues(t, expectedJson.OclcNumber, attributes.OclcNumber)

	// Resolve and verify relationships
	relData := actual.JsonApiRelationships

	// Abstract
	assert.Equal(t, 2, len(expectedJson.Abstract))
	assert.Equal(t, len(expectedJson.Abstract), len(relData.Abstract.Data))
	for i := range relData.Abstract.Data {
		assert.Equal(t, expectedJson.Abstract[i].Value, relData.Abstract.Data[i].value())
		assert.Equal(t, expectedJson.Abstract[i].LangCode, relData.Abstract.Data[i].langCode(t))
	}

	// Access Rights
	assert.Equal(t, 2, len(expectedJson.AccessRights))
	assert.Equal(t, len(expectedJson.AccessRights), len(relData.AccessRights.Data))
	for i := range relData.AccessRights.Data {
		expectedAccessRights := &JsonApiAccessRights{}
		relData.AccessRights.Data[i].resolve(t, expectedAccessRights)
		assert.Equal(t, expectedJson.AccessRights[i], expectedAccessRights.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Alt title
	assert.Equal(t, 2, len(expectedJson.AltTitle))
	assert.Equal(t, len(expectedJson.AltTitle), len(relData.AltTitle.Data))
	for i := range relData.AltTitle.Data {
		assert.Equal(t, expectedJson.AltTitle[i].Value, relData.AltTitle.Data[i].value())
		assert.Equal(t, expectedJson.AltTitle[i].LangCode, relData.AltTitle.Data[i].langCode(t))
	}

	// Contributor
	// TODO: type introspection if Contributor can hold some type other than person
	assert.Equal(t, 2, len(expectedJson.Contributor))
	assert.Equal(t, len(expectedJson.Contributor), len(relData.Contributor.Data))
	for i := range relData.Contributor.Data {
		actualPerson := &JsonApiPerson{}
		relData.Contributor.Data[i].resolve(t, actualPerson)
		actualRelType, err := relData.Contributor.Data[i].metaString("rel_type")
		assert.Nil(t, err)
		assert.Equal(t, expectedJson.Contributor[i].RelType, actualRelType)
		assert.Equal(t, expectedJson.Contributor[i].Name, actualPerson.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Copyright And Use
	actualCopyrightAndUse := &JsonApiCopyrightAndUse{}
	relData.CopyrightAndUse.Data.resolve(t, actualCopyrightAndUse)
	assert.Equal(t, expectedJson.CopyrightAndUse, actualCopyrightAndUse.JsonApiData[0].JsonApiAttributes.Name)

	// Copyright Holder
	// TODO: type introspection if Copyright Holder can hold some type other than person
	assert.Equal(t, 2, len(expectedJson.CopyrightHolder))
	assert.Equal(t, len(expectedJson.CopyrightHolder), len(relData.CopyrightHolder.Data))
	for i := range relData.CopyrightHolder.Data {
		actualPerson := &JsonApiPerson{}
		relData.CopyrightHolder.Data[i].resolve(t, actualPerson)
		assert.Equal(t, expectedJson.CopyrightHolder[i], actualPerson.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Creator
	// TODO: type introspection if Creator can hold some type other than person
	assert.Equal(t, 2, len(expectedJson.Creator))
	assert.Equal(t, len(expectedJson.Creator), len(relData.Creator.Data))
	for i := range relData.Creator.Data {
		actualPerson := &JsonApiPerson{}
		relData.Creator.Data[i].resolve(t, actualPerson)
		actualRelType, err := relData.Creator.Data[i].metaString("rel_type")
		assert.Nil(t, err)
		assert.Equal(t, expectedJson.Creator[i].Name, actualPerson.JsonApiData[0].JsonApiAttributes.Name)
		assert.Equal(t, expectedJson.Creator[i].RelType, actualRelType)
	}

	// Description
	assert.Equal(t, 2, len(expectedJson.Description))
	assert.Equal(t, len(expectedJson.Description), len(relData.Description.Data))
	for i := range relData.Description.Data {
		assert.Equal(t, expectedJson.Description[i].Value, relData.Description.Data[i].value())
		assert.Equal(t, expectedJson.Description[i].LangCode, relData.Description.Data[i].langCode(t))
	}

	// Display Hint

	hint := &JsonApiIslandoraDisplay{}
	relData.DisplayHint.Data.resolve(t, hint)
	assert.Equal(t, expectedJson.DisplayHint, hint.JsonApiData[0].JsonApiAttributes.Name)

	// Digital Publisher
	// TODO: type introspection if Digital Publisher can hold some type other than corporate body
	assert.Equal(t, 2, len(expectedJson.DigitalPublisher))
	assert.Equal(t, len(expectedJson.DigitalPublisher), len(relData.DigitalPublisher.Data))
	for i := range relData.DigitalPublisher.Data {
		corpBod := &JsonApiCorporateBody{}
		relData.DigitalPublisher.Data[i].resolve(t, corpBod)
		assert.Equal(t, expectedJson.DigitalPublisher[i], corpBod.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Genre
	assert.Equal(t, 2, len(expectedJson.Genre))
	assert.Equal(t, len(expectedJson.Genre), len(relData.Genre.Data))
	for i := range relData.Genre.Data {
		genre := &JsonApiGenre{}
		relData.Genre.Data[i].resolve(t, genre)
		assert.Equal(t, expectedJson.Genre[i], genre.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Member Of
	assert.Equal(t, 2, len(expectedJson.MemberOf))
	assert.Equal(t, len(expectedJson.MemberOf), len(relData.MemberOf.Data))
	for i := range relData.MemberOf.Data {
		collection := &JsonApiCollection{}
		relData.MemberOf.Data[i].resolve(t, collection)
		assert.Equal(t, expectedJson.MemberOf[i], collection.JsonApiData[0].JsonApiAttributes.Title)
	}

	// Model
	model := &JsonApiIslandoraModel{}
	relData.Model.Data.resolve(t, model)
	assert.Equal(t, expectedJson.Model.Name, model.JsonApiData[0].JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Model.ExternalUri, model.JsonApiData[0].JsonApiAttributes.ExternalUri.Uri)

	// Publisher
	// TODO: introspect on type if field value will be anything other than a corporate body
	assert.Equal(t, 2, len(expectedJson.Publisher))
	assert.EqualValues(t, len(expectedJson.Publisher), len(relData.Publisher.Data))
	for i := range relData.Publisher.Data {
		pub := &JsonApiCorporateBody{}
		relData.Publisher.Data[i].resolve(t, pub)
		assert.Equal(t, expectedJson.Publisher[i], pub.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Publisher Country (but really can be any geolocation)
	assert.Equal(t, 2, len(expectedJson.PublisherCountry))
	assert.EqualValues(t, len(expectedJson.PublisherCountry), len(relData.PublisherCountry.Data))
	for i := range relData.PublisherCountry.Data {
		loc := &JsonApiGeolocation{}
		relData.PublisherCountry.Data[i].resolve(t, loc)
		assert.Equal(t, expectedJson.PublisherCountry[i], loc.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Resource Type
	assert.Equal(t, 2, len(expectedJson.ResourceType))
	assert.Equal(t, len(expectedJson.ResourceType), len(relData.ResourceType.Data))
	for i := range relData.ResourceType.Data {
		resource := &JsonApiResourceType{}
		relData.ResourceType.Data[i].resolve(t, resource)
		assert.Equal(t, expectedJson.ResourceType[i], resource.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Spatial Coverage
	assert.Equal(t, 2, len(expectedJson.SpatialCoverage))
	assert.Equal(t, len(expectedJson.SpatialCoverage), len(relData.SpatialCoverage.Data))
	for i := range relData.SpatialCoverage.Data {
		loc := &JsonApiGeolocation{}
		relData.SpatialCoverage.Data[i].resolve(t, loc)
		assert.Equal(t, expectedJson.SpatialCoverage[i], loc.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Subject
	assert.Equal(t, 2, len(expectedJson.Subject))
	assert.Equal(t, len(expectedJson.Subject), len(relData.Subject.Data))
	for i := range relData.Subject.Data {
		subj := &JsonApiSubject{}
		relData.Subject.Data[i].resolve(t, subj)
		assert.Equal(t, expectedJson.Subject[i], subj.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Table of Contents
	assert.Equal(t, 2, len(expectedJson.TableOfContents))
	assert.Equal(t, len(expectedJson.TableOfContents), len(relData.TableOfContents.Data))
	for i := range relData.TableOfContents.Data {
		assert.Equal(t, expectedJson.TableOfContents[i].LangCode, relData.TableOfContents.Data[i].langCode(t))
		assert.Equal(t, expectedJson.TableOfContents[i].Value, relData.TableOfContents.Data[i].value())
	}
}

func Test_VerifyMediaAndFile(t *testing.T) {

}

// Searches the file system for the named file.  The `name` should not contain any path components or separators.
//
// This function allows for an IDE to discover test resources while allowing for IDC test framework (the one invoked by
// `make test`) to discover those same resources without hard coding paths.  Instead, this function makes some
// assumptions about where tests are invoked from, and the directory structure underneath the TestBaseDir.
func findExpectedJson(t *testing.T, name string) string {
	// the resolved json file, including its path relative to the working directory.
	var expectedJsonFile string

	// attempt to discover TestBaseDir from the current working directory, which will work if we are invoked by the
	// IDC 'make test' target.
	filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		assert.Nil(t, err)
		// Resolve the expected json file relative to TestBaseDir (note the assumptions made about the directory structure)
		if info.IsDir() && info.Name() == TestBasedir {
			expectedJsonFile = filepath.Join(path, "verification", "expected", name)
			return errors.New(fmt.Sprintf("Found test basedir %s", path))
		}
		return nil
	})

	if expectedJsonFile != "" {
		return expectedJsonFile
	}

	// if the TestBaseDir is not found, that means we are probably being invoked from within that directory (e.g. by an
	// IDE or CLI)
	filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		assert.Nil(t, err)
		// Resolve the json file relative to the directory name `expected` (note the assumptions made about the directory
		// structure)
		if info.IsDir() && info.Name() == "expected" {
			expectedJsonFile = filepath.Join(path, name)
			return errors.New(fmt.Sprintf("Found test basedir %s", path))
		}
		return nil
	})

	assert.NotNil(t, expectedJsonFile)
	assert.NotEmpty(t, expectedJsonFile)
	return expectedJsonFile
}

// Locates the JSON file referenced by 'filename' and unmarshals it into the provided 'value'.  Any errors encountered
// will fail the test.
//
// Note that 'filename' should not contain any path components.  It is resolved to a path by
// findExpectedJson(...)
func unmarshalJson(t *testing.T, filename string, value interface{}) {
	expectedJsonFile := findExpectedJson(t, filename)
	expectedFile, err := os.Open(expectedJsonFile)
	defer func() { expectedFile.Close() }()
	assert.Nil(t, err, "Error opening file %s: %s", expectedJsonFile, err)

	// read expected json from file
	err = json.NewDecoder(expectedFile).Decode(value)
	assert.Nil(t, err, "Error decoding the content of file %s as JSON: %s", expectedJsonFile, err)
}

// Unmarshal a JSONAPI response body and assert that exactly one data element is present
func unmarshalSingleResponse(t *testing.T, body []byte, res *http.Response, value *JsonApiResponse) *JsonApiResponse {
	err := json.Unmarshal(body, value)
	assert.Nil(t, err, "Error unmarshaling JSONAPI response body: %s", err)
	assert.Equal(t, 1, len(value.Data), "Exactly one JSONAPI data element is expected in the response, but found %d element(s)", len(value.Data))
	return value
}

// Successfully GET the content at the URL and return the response and body.
func getResource(t *testing.T, u string) (*http.Response, []byte) {
	res, err := http.Get(u)
	log.Printf("Retrieving %s", u)
	assert.Nil(t, err, "encountered error requesting %s: %s", u, err)
	assert.Equal(t, 200, res.StatusCode, "%d status encountered when requesting %s", res.StatusCode, u)
	body, err := ioutil.ReadAll(res.Body)
	assert.Nil(t, err, "error encountered reading response body from %s: %s", u, err)
	return res, body
}
