package main

import (
	"encoding/json"
	"fmt"
	"github.com/stretchr/testify/require"
	"log"
	"net/http"
	"os"
	"strings"
	"testing"
	"text/template"
	"time"

	"github.com/jhu-idc/idc-golang/drupal/env"
	"github.com/jhu-idc/idc-golang/drupal/fs"
	"github.com/jhu-idc/idc-golang/drupal/jsonapi"
	"github.com/jhu-idc/idc-golang/drupal/model"
	. "github.com/logrusorgru/aurora/v3"
	"github.com/stretchr/testify/assert"
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

	// Env var name for the base URL to media assets
	AssetsBaseUrl = "BASE_ASSETS_URL"
)

var (
	drupalAdmin = env.GetEnvOr("DRUPAL_DEFAULT_ACCOUNT_NAME", "admin")
	drupalPass  = env.GetEnvOr("DRUPAL_DEFAULT_ACCOUNT_PASSWORD", "password")

	// the following are used to process the expected uris for files associated with drupal media, and output
	// the 'url' and 'value' components of a Drupal File.  templates are used because the urls are now parameterized
	// with the date the file was uploaded into the system.
	//
	//
	urlTmpl, _   = template.New("url").Parse("{{ print \"/system/files/\" print .Date print \"/\" print .File }}")
	valueTmpl, _ = template.New("value").Parse("{{ print \"private://\" print .Date print \"/\" print .File }}")

	// input to the template which is pre-populated with the current date.
	tmplInput = &struct {
		Date string
		File string
	}{
		fmt.Sprintf(time.Now().Format("2006-01-02")),
		"",
	}
)

func TestMain(m *testing.M) {
	var (
		res *http.Response
		err error
	)

	assetsUrl := env.AssetsBaseUrlOr("http://migration-assets/assets/")
	if assetsUrl != "" {
		if res, err = http.Get(assetsUrl); err != nil {
			log.Println(Sprintf(Red("Assets container (%s) is not up, media tests will fail: %s"), assetsUrl, BrightRed(err.Error())))
		} else {
			defer res.Body.Close()
			if res.StatusCode != 200 {
				log.Println(Sprintf(Red("Unexpected status code %d from %s, media tests will fail."),
					res.StatusCode, assetsUrl))
			}
		}
	} else {
		log.Println(Sprintf(Red("%s env var is not defined, media tests will fail."), AssetsBaseUrl))
	}

	os.Exit(m.Run())
}

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
	expectedJson := model.ExpectedPerson{}
	log.Printf("Test Person file: %s and %s", fileName, restOfName)
	unmarshalExpectedJson(t, fileName, &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "person", expectedJson.Bundle)
	assert.Equal(t, restOfName, expectedJson.RestOfName[0])
	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	personRes := &model.JsonApiPerson{}
	u.GetSingle(personRes)

	// for each field in expected json,
	//   see if the expected field matches the actual field from retrieved json
	//   resolve relationships if required
	//     - required for schema:knows
	actual := personRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.PrimaryName, actual.JsonApiAttributes.PrimaryPartOfName)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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
	u.Value = expectedJson.Knows[0]

	// retrieve json of the resolved entity from the jsonapi
	personRes = &model.JsonApiPerson{}
	u.GetSingle(personRes)
	relSchemaKnows := personRes.JsonApiData[0]

	// sanity
	assert.Equal(t, relSchemaKnows.Type.Bundle(), "person")
	assert.Equal(t, relSchemaKnows.Type.Entity(), "taxonomy_term")

	// test
	assert.Equal(t, expectedJson.Knows[0], relSchemaKnows.JsonApiAttributes.Name)
}

// Taxonomy term name lengths are now configurable in settings.local.php, currently set at 2000 for
// a name field. This test ensures that these long names can be entered via ingest.
func Test_VerifyTaxonomyTermLongNamePerson(t *testing.T) {

	expectedJson := model.ExpectedPerson{}
	unmarshalExpectedJson(t, "taxonomy-person-03.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "person", expectedJson.Bundle)
	assert.Equal(t, "Lorem", expectedJson.RestOfName[0])

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "field_preferred_name_fuller_form",
		Value:        expectedJson.FullerForm[0],
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	personRes := &model.JsonApiPerson{}
	u.GetSingle(personRes)

	// If we get this far, it means we found it by it's name, so that's a good start. Now check a few other things
	// as a sanity test. This is not a comprehensive test of the taxonomy as we've already checked things
	// like full terms in other tests.
	actual := personRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
	assert.Equal(t, expectedJson.PrimaryName, actual.JsonApiAttributes.PrimaryPartOfName)
	assert.ElementsMatch(t, expectedJson.RestOfName, actual.JsonApiAttributes.PreferredNameRest)
	assert.ElementsMatch(t, expectedJson.AltName, actual.JsonApiAttributes.PersonAlternateName)
	assert.Equal(t, expectedJson.Authority[0].Uri, actual.JsonApiAttributes.Authority[0].Uri)
	assert.Equal(t, expectedJson.Authority[0].Type, actual.JsonApiAttributes.Authority[0].Source)
}

func Test_VerifyTaxonomyTermAccessRights(t *testing.T) {
	expectedJson := model.ExpectedAccessRights{}
	unmarshalExpectedJson(t, "taxonomy-accessrights.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "access_rights", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	accessRightsRes := &model.JsonApiAccessRights{}
	u.GetSingle(accessRightsRes)

	actual := accessRightsRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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

// Verifies that the Islandora Access Terms migrated by testcafe accessterms.csv
// match the expected fields and values present in taxonomy-person-01.json
// This is testing a term with no parent
func Test_VerifyTaxonomyTermIslandoraAccessTerms_Term1(t *testing.T) {
	verifyTaxonomyTermIslandoraAccessTerms(t, "taxonomy-accessterms-01.json")
}

// Verifies that the Islandora Access Terms migrated by testcafe accessterms.csv
// match the expected fields and values present in taxonomy-person-02.json
// This is testing a term with a parent
func Test_VerifyTaxonomyTermIslandoraAccessTerms_Term2(t *testing.T) {
	verifyTaxonomyTermIslandoraAccessTerms(t, "taxonomy-accessterms-02.json")
}

func verifyTaxonomyTermIslandoraAccessTerms(t *testing.T, fileName string) {
	expectedJson := model.ExpectedIslandoraAccessTerms{}

	unmarshalExpectedJson(t, fileName, &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "islandora_access", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	accessTermsRes := &model.JsonApiIslandoraAccessTerms{}
	u.Get(accessTermsRes)

	actual := accessTermsRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
	assert.Equal(t, expectedJson.Description.Format, actual.JsonApiAttributes.Description.Format)
	assert.Equal(t, expectedJson.Description.Value, actual.JsonApiAttributes.Description.Value)
	assert.Equal(t, expectedJson.Description.Processed, actual.JsonApiAttributes.Description.Processed)

	// one test doesn't have a parent.
	if len(expectedJson.Parent) != 0 {
		u.Value = expectedJson.Parent[0]

		// retrieve json of the resolved entity from the jsonapi
		accessTermsRes = &model.JsonApiIslandoraAccessTerms{}
		u.Get(accessTermsRes)
		relParent := accessTermsRes.JsonApiData[0]

		// sanity
		assert.Equal(t, relParent.Type.Bundle(), "islandora_access")
		assert.Equal(t, relParent.Type.Entity(), "taxonomy_term")

		// test
		assert.Equal(t, expectedJson.Parent[0], relParent.JsonApiAttributes.Name)
	}
}

func Test_VerifyTaxonomyCopyrightAndUse(t *testing.T) {
	expectedJson := model.ExpectedCopyrightAndUse{}
	unmarshalExpectedJson(t, "taxonomy-copyrightanduse.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "copyright_and_use", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	copyrightRes := &model.JsonApiCopyrightAndUse{}
	u.GetSingle(copyrightRes)

	actual := copyrightRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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

func Test_VerifyTaxonomyTermResourceType(t *testing.T) {
	expectedJson := model.ExpectedResourceType{}
	unmarshalExpectedJson(t, "taxonomy-resourcetypes.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "resource_types", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiResourceType{}
	u.GetSingle(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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
	expectedJson := model.ExpectedFamily{}
	unmarshalExpectedJson(t, "taxonomy-family-01.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "family", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	familyres := &model.JsonApiFamily{}
	u.GetSingle(familyres)
	sourceId := familyres.JsonApiData[0].Id
	assert.NotEmpty(t, sourceId)

	actual := familyres.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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
	u.Value = expectedJson.KnowsAbout[0]

	// retrieve json of the resolved entity from the jsonapi
	familyres = &model.JsonApiFamily{}
	u.GetSingle(familyres)
	relSchemaKnowsAbout := familyres.JsonApiData[0]

	// sanity
	assert.Equal(t, relSchemaKnowsAbout.Type.Bundle(), "family")
	assert.Equal(t, relSchemaKnowsAbout.Type.Entity(), "taxonomy_term")

	// test
	assert.Equal(t, expectedJson.KnowsAbout[0], relSchemaKnowsAbout.JsonApiAttributes.Name)

	// assert the reciprocal relationship holds (e.g. the id referenced by the target is the same as the source id)
	assert.Equal(t, sourceId, relSchemaKnowsAbout.JsonApiRelationships.Relationships.Data[0].Id)
}

func Test_VerifyTaxonomyTermGenre(t *testing.T) {
	expectedJson := model.ExpectedGenre{}
	unmarshalExpectedJson(t, "taxonomy-genre.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "genre", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	genreRes := &model.JsonApiGenre{}
	u.GetSingle(genreRes)

	actual := genreRes.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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
	expectedJson := model.ExpectedGeolocation{}
	unmarshalExpectedJson(t, "taxonomy-geolocation.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "geo_location", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiGeolocation{}
	u.GetSingle(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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
	assert.Equal(t, 2, len(actual.JsonApiAttributes.Broader))
	for i, v := range actual.JsonApiAttributes.Broader {
		assert.Equal(t, expectedJson.Broader[i].Uri, v.Uri)
	}
}

func Test_VerifyTaxonomySubject(t *testing.T) {
	expectedJson := model.ExpectedSubject{}
	unmarshalExpectedJson(t, "taxonomy-subject.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "subject", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiSubject{}
	u.GetSingle(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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
	expectedJson := model.ExpectedLanguage{}
	unmarshalExpectedJson(t, "taxonomy-language.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "language", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiLanguage{}
	u.GetSingle(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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
	expectedJson := model.ExpectedCorporateBody{}
	unmarshalExpectedJson(t, "taxonomy-corporatebody-02.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "taxonomy_term", expectedJson.Type)
	assert.Equal(t, "corporate_body", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiCorporateBody{}
	u.GetSingle(res)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Name, actual.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
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
	assert.Equal(t, "taxonomy_term", relData[0].Type.Entity())
	assert.Equal(t, "corporate_body", relData[0].Type.Bundle())
	assert.Equal(t, expectedJson.Relationship[0].Rel, relData[0].Meta["rel_type"])
	u = &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: relData[0].Type.Entity(),
		DrupalBundle: relData[0].Type.Bundle(),
		Filter:       "id",
		Value:        relData[0].Id,
	}
	target := &model.JsonApiCorporateBody{}
	u.GetSingle(target)
	assert.Equal(t, expectedJson.Relationship[0].Name, target.JsonApiData[0].JsonApiAttributes.Name)

	//  "Parent Organization" -> 'schema:subOrganization' -> "My Corporate Body"
	assert.Equal(t, target.JsonApiData[0].JsonApiRelationships.Relationships.Data[0].Id, actual.Id)
	assert.Equal(t, target.JsonApiData[0].JsonApiRelationships.Relationships.Data[0].Meta["rel_type"], "schema:subOrganization")
}

func Test_VerifyCollection(t *testing.T) {
	expectedJson := model.ExpectedCollection{}
	unmarshalExpectedJson(t, "collection-01.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "node", expectedJson.Type)
	assert.Equal(t, "collection_object", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "title",
		Value:        expectedJson.Title,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiCollection{}
	u.GetSingle(res)
	sourceId := res.JsonApiData[0].Id
	assert.NotEmpty(t, sourceId)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Title, actual.JsonApiAttributes.Title)
	assert.Equal(t, expectedJson.UniqueId, actual.JsonApiAttributes.UniqueId)
	assert.Equal(t, expectedJson.ContactEmail, actual.JsonApiAttributes.ContactEmail)
	assert.Equal(t, expectedJson.ContactName, actual.JsonApiAttributes.ContactName)
	assert.ElementsMatch(t, expectedJson.CollectionNumber, actual.JsonApiAttributes.CollectionNumber)

	// Check Finding Aids
	for i := range actual.JsonApiAttributes.FindingAid {
		assert.Equal(t, expectedJson.FindingAid[i].Uri, actual.JsonApiAttributes.FindingAid[i].Uri)
	}

	relData := res.JsonApiData[0].JsonApiRelationships

	// Resolve and verify title language
	assert.NotNil(t, relData.TitleLanguage.Data)
	assert.Equal(t, "taxonomy_term", relData.TitleLanguage.Data.Type.Entity())
	assert.Equal(t, "language", relData.TitleLanguage.Data.Type.Bundle())
	assert.Equal(t, expectedJson.TitleLangCode, relData.TitleLanguage.Data.LangCode(t))
	// Resolve and verify alternate title values and languages
	assert.NotNil(t, relData.AltTitle.Data)
	assert.Equal(t, 2, len(relData.AltTitle.Data))
	assert.Equal(t, len(expectedJson.AltTitle), len(relData.AltTitle.Data))
	for i, altTitleData := range relData.AltTitle.Data {
		assert.Equal(t, "taxonomy_term", altTitleData.Type.Entity())
		assert.Equal(t, "language", altTitleData.Type.Bundle())
		assert.Equal(t, expectedJson.AltTitle[i].Value, altTitleData.Value())
		assert.Equal(t, expectedJson.AltTitle[i].LangCode, altTitleData.LangCode(t))
	}

	// Resolve and verify description values and languages
	assert.NotNil(t, relData.Description)
	assert.Equal(t, 2, len(relData.Description.Data))
	assert.Equal(t, len(expectedJson.Description), len(relData.Description.Data))
	for i, descData := range relData.Description.Data {
		assert.Equal(t, "taxonomy_term", descData.Type.Entity())
		assert.Equal(t, "language", descData.Type.Bundle())
		assert.Equal(t, expectedJson.Description[i].Value, descData.Value())
		assert.Equal(t, expectedJson.Description[i].LangCode, descData.LangCode(t))
	}

	// Resolve and verify member_of values
	assert.NotNil(t, relData.MemberOf)
	assert.Equal(t, "node", relData.MemberOf.Data.Type.Entity())
	assert.Equal(t, "collection_object", relData.MemberOf.Data.Type.Bundle())
	memberCol := model.JsonApiCollection{}
	relData.MemberOf.Data.Resolve(t, &memberCol)
	u = &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: relData.MemberOf.Data.Type.Entity(),
		DrupalBundle: relData.MemberOf.Data.Type.Bundle(),
		Filter:       "id",
		Value:        relData.MemberOf.Data.Id,
	}
	u.GetSingle(&memberCol)

	assert.Equal(t, expectedJson.MemberOf, memberCol.JsonApiData[0].JsonApiAttributes.Title)

	// Resolve and verify access_terms values
	assert.NotNil(t, relData.AccessTerms)
	assert.Equal(t, 1, len(relData.AccessTerms.Data))
	assert.Equal(t, len(expectedJson.AccessTerms), len(relData.AccessTerms.Data))
	for i, accessTermsData := range relData.AccessTerms.Data {
		assert.Equal(t, "taxonomy_term", accessTermsData.Type.Entity())
		assert.Equal(t, "islandora_access", accessTermsData.Type.Bundle())

		u = &jsonapi.JsonApiUrl{
			T:            t,
			BaseUrl:      DrupalBaseurl,
			DrupalEntity: accessTermsData.Type.Entity(),
			DrupalBundle: accessTermsData.Type.Bundle(),
			Filter:       "id",
			Value:        accessTermsData.Id,
		}
		accessTerm := model.JsonApiIslandoraAccessTerms{}
		u.Get(&accessTerm)

		assert.Equal(t, expectedJson.AccessTerms[i], accessTerm.JsonApiData[0].JsonApiAttributes.Name)
	}
}

// Node title lengths are now configurable in settings.local.php, currently set at 500 for a node
// This test ensures that these long node titles can be entered via ingest.
func Test_VerifyLongNodeTitle(t *testing.T) {
	expectedJson := model.ExpectedCollection{}
	unmarshalExpectedJson(t, "collection-03.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "node", expectedJson.Type)
	assert.Equal(t, "collection_object", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "title",
		Value:        expectedJson.Title,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiCollection{}
	u.GetSingle(res)
	sourceId := res.JsonApiData[0].Id
	assert.NotEmpty(t, sourceId)

	actual := res.JsonApiData[0]
	assert.Equal(t, expectedJson.Type, actual.Type.Entity())
	assert.Equal(t, expectedJson.Bundle, actual.Type.Bundle())
	assert.Equal(t, expectedJson.Title, actual.JsonApiAttributes.Title)
}

func Test_VerifyRepositoryItem(t *testing.T) {
	expectedJson := model.ExpectedRepoObj{}
	unmarshalExpectedJson(t, "item-01.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "node", expectedJson.Type)
	assert.Equal(t, "islandora_object", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "title",
		Value:        expectedJson.Title,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiIslandoraObj{}
	u.GetSingle(res)
	actual := res.JsonApiData[0]
	sourceId := actual.Id
	assert.NotEmpty(t, sourceId)

	// Verify attributes
	attributes := actual.JsonApiAttributes

	// Title
	assert.Equal(t, expectedJson.Title, attributes.Title)

	// Check unique id
	assert.Equal(t, expectedJson.UniqueId, attributes.UniqueId)

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
	for i := range attributes.LibraryCatalogLink {
		assert.Equal(t, expectedJson.LibraryCatalogLink[i], attributes.LibraryCatalogLink[i].Uri)
	}

	// Extent
	assert.Equal(t, expectedJson.Extent, attributes.Extent)

	// Featured Item
	assert.Equal(t, expectedJson.FeaturedItem, attributes.FeaturedItem)

	// Finding Aid
	for i := range attributes.FindingAid {
		assert.Equal(t, expectedJson.FindingAid[i].Uri, attributes.FindingAid[i].Uri)
	}

	// Geoportal Link
	assert.Equal(t, expectedJson.GeoportalLink, attributes.GeoportalLink.Uri)

	// Issn
	assert.Equal(t, expectedJson.Issn, attributes.Issn)

	// Is Part Of
	assert.Equal(t, expectedJson.IsPartOf, attributes.IsPartOf.Uri)

	// Item Barcode
	for i := range attributes.ItemBarcode {
		assert.Equal(t, expectedJson.ItemBarcode[i], attributes.ItemBarcode[i])
	}

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
		assert.Equal(t, expectedJson.Abstract[i].Value, relData.Abstract.Data[i].Value())
		assert.Equal(t, expectedJson.Abstract[i].LangCode, relData.Abstract.Data[i].LangCode(t))
	}

	// Access Rights
	assert.Equal(t, 2, len(expectedJson.AccessRights))
	assert.Equal(t, len(expectedJson.AccessRights), len(relData.AccessRights.Data))
	for i := range relData.AccessRights.Data {
		expectedAccessRights := &model.JsonApiAccessRights{}
		relData.AccessRights.Data[i].Resolve(t, expectedAccessRights)
		assert.Contains(t, expectedJson.AccessRights, expectedAccessRights.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Access Terms
	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(relData.AccessTerms.Data))
	for i := range relData.AccessTerms.Data {
		expectedAccessTerms := &model.JsonApiIslandoraAccessTerms{}
		relData.AccessTerms.Data[i].Resolve(t, expectedAccessTerms)
		assert.Contains(t, expectedJson.AccessTerms, expectedAccessTerms.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Alt title
	assert.Equal(t, 2, len(expectedJson.AltTitle))
	assert.Equal(t, len(expectedJson.AltTitle), len(relData.AltTitle.Data))
	for i := range relData.AltTitle.Data {
		assert.Equal(t, expectedJson.AltTitle[i].Value, relData.AltTitle.Data[i].Value())
		assert.Equal(t, expectedJson.AltTitle[i].LangCode, relData.AltTitle.Data[i].LangCode(t))
	}

	// Contributor
	// TODO: type introspection if Contributor can hold some type other than person
	assert.Equal(t, 2, len(expectedJson.Contributor))
	assert.Equal(t, len(expectedJson.Contributor), len(relData.Contributor.Data))
	for i := range relData.Contributor.Data {
		actualPerson := &model.JsonApiPerson{}
		relData.Contributor.Data[i].Resolve(t, actualPerson)
		actualRelType, err := relData.Contributor.Data[i].MetaString("rel_type")
		assert.Nil(t, err)
		assert.Equal(t, expectedJson.Contributor[i].RelType, actualRelType)
		assert.Equal(t, expectedJson.Contributor[i].Name, actualPerson.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Copyright And Use
	actualCopyrightAndUse := &model.JsonApiCopyrightAndUse{}
	relData.CopyrightAndUse.Data.Resolve(t, actualCopyrightAndUse)
	assert.Equal(t, expectedJson.CopyrightAndUse, actualCopyrightAndUse.JsonApiData[0].JsonApiAttributes.Name)

	// Copyright Holder
	// TODO: type introspection if Copyright Holder can hold some type other than person
	assert.Equal(t, 2, len(expectedJson.CopyrightHolder))
	assert.Equal(t, len(expectedJson.CopyrightHolder), len(relData.CopyrightHolder.Data))
	for i := range relData.CopyrightHolder.Data {
		actualPerson := &model.JsonApiPerson{}
		relData.CopyrightHolder.Data[i].Resolve(t, actualPerson)
		assert.Equal(t, expectedJson.CopyrightHolder[i], actualPerson.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Creator
	// TODO: type introspection if Creator can hold some type other than person
	assert.Equal(t, 2, len(expectedJson.Creator))
	assert.Equal(t, len(expectedJson.Creator), len(relData.Creator.Data))
	for i := range relData.Creator.Data {
		actualPerson := &model.JsonApiPerson{}
		relData.Creator.Data[i].Resolve(t, actualPerson)
		actualRelType, err := relData.Creator.Data[i].MetaString("rel_type")
		assert.Nil(t, err)
		assert.Equal(t, expectedJson.Creator[i].Name, actualPerson.JsonApiData[0].JsonApiAttributes.Name)
		assert.Equal(t, expectedJson.Creator[i].RelType, actualRelType)
	}

	// Custodial History
	assert.Equal(t, 2, len(expectedJson.CustodialHistory))
	assert.Equal(t, len(expectedJson.CustodialHistory), len(relData.CustodialHistory.Data))
	for i := range relData.CustodialHistory.Data {
		assert.Equal(t, expectedJson.CustodialHistory[i].Value, relData.CustodialHistory.Data[i].Value())
		assert.Equal(t, expectedJson.CustodialHistory[i].LangCode, relData.CustodialHistory.Data[i].LangCode(t))
	}

	// Description
	assert.Equal(t, 2, len(expectedJson.Description))
	assert.Equal(t, len(expectedJson.Description), len(relData.Description.Data))
	for i := range relData.Description.Data {
		assert.Equal(t, expectedJson.Description[i].Value, relData.Description.Data[i].Value())
		assert.Equal(t, expectedJson.Description[i].LangCode, relData.Description.Data[i].LangCode(t))
	}

	// Display Hint

	hint := &model.JsonApiIslandoraDisplay{}
	relData.DisplayHint.Data.Resolve(t, hint)
	assert.Equal(t, expectedJson.DisplayHint, hint.JsonApiData[0].JsonApiAttributes.Name)

	// Digital Publisher
	// TODO: type introspection if Digital Publisher can hold some type other than corporate body
	assert.Equal(t, 2, len(expectedJson.DigitalPublisher))
	assert.Equal(t, len(expectedJson.DigitalPublisher), len(relData.DigitalPublisher.Data))
	for i := range relData.DigitalPublisher.Data {
		corpBod := &model.JsonApiCorporateBody{}
		relData.DigitalPublisher.Data[i].Resolve(t, corpBod)
		assert.Contains(t, expectedJson.DigitalPublisher, corpBod.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Genre
	assert.Equal(t, 2, len(expectedJson.Genre))
	assert.Equal(t, len(expectedJson.Genre), len(relData.Genre.Data))
	for i := range relData.Genre.Data {
		genre := &model.JsonApiGenre{}
		relData.Genre.Data[i].Resolve(t, genre)
		assert.Contains(t, expectedJson.Genre, genre.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Member Of
	assert.NotNil(t, relData.MemberOf)
	collection := &model.JsonApiCollection{}
	relData.MemberOf.Data.Resolve(t, collection)
	assert.Equal(t, expectedJson.MemberOf, collection.JsonApiData[0].JsonApiAttributes.Title)

	// Model
	islandoraModel := &model.JsonApiIslandoraModel{}
	relData.Model.Data.Resolve(t, islandoraModel)
	assert.Equal(t, expectedJson.Model.Name, islandoraModel.JsonApiData[0].JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Model.ExternalUri, islandoraModel.JsonApiData[0].JsonApiAttributes.ExternalUri.Uri)

	// Publisher
	// TODO: introspect on type if field value will be anything other than a corporate body
	assert.Equal(t, 2, len(expectedJson.Publisher))
	assert.EqualValues(t, len(expectedJson.Publisher), len(relData.Publisher.Data))
	for i := range relData.Publisher.Data {
		pub := &model.JsonApiCorporateBody{}
		relData.Publisher.Data[i].Resolve(t, pub)
		assert.Contains(t, expectedJson.Publisher, pub.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Publisher Country (but really can be any geolocation)
	assert.Equal(t, 2, len(expectedJson.PublisherCountry))
	assert.EqualValues(t, len(expectedJson.PublisherCountry), len(relData.PublisherCountry.Data))
	for i := range relData.PublisherCountry.Data {
		loc := &model.JsonApiGeolocation{}
		relData.PublisherCountry.Data[i].Resolve(t, loc)
		assert.Contains(t, expectedJson.PublisherCountry, loc.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Resource Type
	assert.Equal(t, 2, len(expectedJson.ResourceType))
	assert.Equal(t, len(expectedJson.ResourceType), len(relData.ResourceType.Data))
	for i := range relData.ResourceType.Data {
		resource := &model.JsonApiResourceType{}
		relData.ResourceType.Data[i].Resolve(t, resource)
		assert.Contains(t, expectedJson.ResourceType, resource.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Spatial Coverage
	assert.Equal(t, 2, len(expectedJson.SpatialCoverage))
	assert.Equal(t, len(expectedJson.SpatialCoverage), len(relData.SpatialCoverage.Data))
	for i := range relData.SpatialCoverage.Data {
		loc := &model.JsonApiGeolocation{}
		relData.SpatialCoverage.Data[i].Resolve(t, loc)
		assert.Contains(t, expectedJson.SpatialCoverage, loc.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Subject
	assert.Equal(t, 2, len(expectedJson.Subject))
	assert.Equal(t, len(expectedJson.Subject), len(relData.Subject.Data))
	for i := range relData.Subject.Data {
		subj := &model.JsonApiSubject{}
		relData.Subject.Data[i].Resolve(t, subj)
		assert.Contains(t, expectedJson.Subject, subj.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Table of Contents
	assert.Equal(t, 2, len(expectedJson.TableOfContents))
	assert.Equal(t, len(expectedJson.TableOfContents), len(relData.TableOfContents.Data))
	for i := range relData.TableOfContents.Data {
		assert.Equal(t, expectedJson.TableOfContents[i].LangCode, relData.TableOfContents.Data[i].LangCode(t))
		assert.Equal(t, expectedJson.TableOfContents[i].Value, relData.TableOfContents.Data[i].Value())
	}

	// Weight
	assert.Equal(t, 10, expectedJson.Weight)
}

// This test is concerned with verifying two things concerning delimiters in ingests:
// 1) that `:` can exist in the name of a taxonomy term and resolve correct
//    (here it's tucked into a subject's name)
// 2) that a `;` in a language value pair behaves fine (in fields like asbtract, description, etc).
func Test_VerifyRepositoryItemWithDelimitersInData(t *testing.T) {
	expectedJson := model.ExpectedRepoObj{}
	unmarshalExpectedJson(t, "item-02.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "node", expectedJson.Type)
	assert.Equal(t, "islandora_object", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedJson.Type,
		DrupalBundle: expectedJson.Bundle,
		Filter:       "title",
		Value:        expectedJson.Title,
	}

	// retrieve json of the migrated entity from the jsonapi and unmarshal the single response
	res := &model.JsonApiIslandoraObj{}
	u.GetSingle(res)
	actual := res.JsonApiData[0]
	sourceId := actual.Id
	assert.NotEmpty(t, sourceId)

	// Verify attributes
	attributes := actual.JsonApiAttributes

	// Title
	assert.Equal(t, expectedJson.Title, attributes.Title)

	// Unique Id
	assert.Equal(t, expectedJson.UniqueId, attributes.UniqueId)

	// Identifiers
	assert.Equal(t, 2, len(expectedJson.DigitalIdentifier))
	assert.EqualValues(t, expectedJson.DigitalIdentifier, attributes.DigitalIdentifier)

	// Resolve and verify relationships
	relData := actual.JsonApiRelationships

	// Abstract
	assert.Equal(t, 2, len(expectedJson.Abstract))
	assert.Equal(t, len(expectedJson.Abstract), len(relData.Abstract.Data))
	for i := range relData.Abstract.Data {
		assert.Equal(t, expectedJson.Abstract[i].Value, relData.Abstract.Data[i].Value())
		assert.Equal(t, expectedJson.Abstract[i].LangCode, relData.Abstract.Data[i].LangCode(t))
	}

	// Alt title
	assert.Equal(t, 2, len(expectedJson.AltTitle))
	assert.Equal(t, len(expectedJson.AltTitle), len(relData.AltTitle.Data))
	for i := range relData.AltTitle.Data {
		assert.Equal(t, expectedJson.AltTitle[i].Value, relData.AltTitle.Data[i].Value())
		assert.Equal(t, expectedJson.AltTitle[i].LangCode, relData.AltTitle.Data[i].LangCode(t))
	}

	// Contributor
	// TODO: type introspection if Contributor can hold some type other than person
	assert.Equal(t, 2, len(expectedJson.Contributor))
	assert.Equal(t, len(expectedJson.Contributor), len(relData.Contributor.Data))
	for i := range relData.Contributor.Data {
		actualPerson := &model.JsonApiPerson{}
		relData.Contributor.Data[i].Resolve(t, actualPerson)
		actualRelType, err := relData.Contributor.Data[i].MetaString("rel_type")
		assert.Nil(t, err)
		assert.Equal(t, expectedJson.Contributor[i].RelType, actualRelType)
		assert.Equal(t, expectedJson.Contributor[i].Name, actualPerson.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Creator
	// TODO: type introspection if Creator can hold some type other than person
	assert.Equal(t, 2, len(expectedJson.Creator))
	assert.Equal(t, len(expectedJson.Creator), len(relData.Creator.Data))
	for i := range relData.Creator.Data {
		actualPerson := &model.JsonApiPerson{}
		relData.Creator.Data[i].Resolve(t, actualPerson)
		actualRelType, err := relData.Creator.Data[i].MetaString("rel_type")
		assert.Nil(t, err)
		assert.Equal(t, expectedJson.Creator[i].Name, actualPerson.JsonApiData[0].JsonApiAttributes.Name)
		assert.Equal(t, expectedJson.Creator[i].RelType, actualRelType)
	}

	// Custodial History
	assert.Equal(t, 2, len(expectedJson.CustodialHistory))
	assert.Equal(t, len(expectedJson.CustodialHistory), len(relData.CustodialHistory.Data))
	for i := range relData.CustodialHistory.Data {
		assert.Equal(t, expectedJson.CustodialHistory[i].Value, relData.CustodialHistory.Data[i].Value())
		assert.Equal(t, expectedJson.CustodialHistory[i].LangCode, relData.CustodialHistory.Data[i].LangCode(t))
	}

	// Description
	assert.Equal(t, 2, len(expectedJson.Description))
	assert.Equal(t, len(expectedJson.Description), len(relData.Description.Data))
	for i := range relData.Description.Data {
		assert.Equal(t, expectedJson.Description[i].Value, relData.Description.Data[i].Value())
		assert.Equal(t, expectedJson.Description[i].LangCode, relData.Description.Data[i].LangCode(t))
	}

	// Subject
	assert.Equal(t, 2, len(expectedJson.Subject))
	assert.Equal(t, len(expectedJson.Subject), len(relData.Subject.Data))
	for i := range relData.Subject.Data {
		subj := &model.JsonApiSubject{}
		relData.Subject.Data[i].Resolve(t, subj)
		assert.Contains(t, expectedJson.Subject, subj.JsonApiData[0].JsonApiAttributes.Name)
	}

	// Table of Contents
	assert.Equal(t, 2, len(expectedJson.TableOfContents))
	assert.Equal(t, len(expectedJson.TableOfContents), len(relData.TableOfContents.Data))
	for i := range relData.TableOfContents.Data {
		assert.Equal(t, expectedJson.TableOfContents[i].LangCode, relData.TableOfContents.Data[i].LangCode(t))
		assert.Equal(t, expectedJson.TableOfContents[i].Value, relData.TableOfContents.Data[i].Value())
	}

	// Weight should not exist
	assert.Empty(t, expectedJson.Weight)
}

// Two media with identical file content will have different File entities, and each File will have its own bitstream.
// That is, there is a 1:1 relationship between the File and the bitstream, even if a byte-for-byte identical bitstream
// was already in the system.
func Test_VerifyDuplicateMediaAndFile(t *testing.T) {
	// There are two Media with this name that were migrated by testcafe; they use the same file, so the File entity
	// linked by these Media should be byte-for-byte identical.  The File entities will be different, and their URIs
	// will be different.
	name := "Fuji Acros Datasheet"

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: "media",
		DrupalBundle: "document",
		Filter:       "name",
		Value:        name,
		Username:     drupalAdmin,
		Password:     drupalPass,
	}

	res := model.JsonApiDocumentMedia{}
	u.Get(&res)

	// Sanity check the response contains what we expect
	assert.NotEmpty(t, res)
	assert.Equal(t, 2, len(res.JsonApiData))
	for i := range res.JsonApiData {
		assert.Equal(t, name, res.JsonApiData[i].JsonApiAttributes.Name)
	}

	var (
		fileEntityId  string
		fileEntityUri string
		resolvedFiles []model.JsonApiFile
	)

	// The two media should have different File entities
	for i := range res.JsonApiData {
		if fileEntityId == "" {
			fileEntityId = res.JsonApiData[i].JsonApiRelationships.File.Data.Id
		} else {
			assert.NotEqual(t, fileEntityId, res.JsonApiData[i].JsonApiRelationships.File.Data.Id)
		}

		// (while we're ranging over the response data, resolve the file entities)
		file := model.JsonApiFile{}
		res.JsonApiData[i].JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
		resolvedFiles = append(resolvedFiles, file)
	}

	// sanity
	assert.Equal(t, 2, len(resolvedFiles))

	// The two media should have different URIs
	for i := range resolvedFiles {
		if fileEntityUri == "" {
			fileEntityUri = resolvedFiles[i].JsonApiData[0].JsonApiAttributes.Uri.Value
		} else {
			assert.NotEqual(t, fileEntityUri, resolvedFiles[i].JsonApiData[0].JsonApiAttributes.Uri.Value)
			// The URIs should differ: 'private://2021-09-09/Fuji_acros_0.pdf' vs 'private://2021-09-09/Fuji_acros.pdf'
			if strings.Contains(fileEntityUri, "Fuji_acros.pdf") {
				sliced := strings.Split(resolvedFiles[i].JsonApiData[0].JsonApiAttributes.Uri.Value, "/")
				assert.Equal(t, "Fuji_acros_0.pdf", sliced[len(sliced)-1])
			} else {
				sliced := strings.Split(fileEntityUri, "/")
				assert.Equal(t, "Fuji_acros_0.pdf", sliced[len(sliced)-1])
			}
		}
	}

	// ensure content can be downloaded
	baseUri := env.BaseUrlOr("https://islandora-idc.traefik.me/")
	for i := range resolvedFiles {
		fileUrl := fmt.Sprintf("%s%s", baseUri, resolvedFiles[i].JsonApiData[0].JsonApiAttributes.Uri.Url)
		fileRes, err := http.Get(fileUrl)
		assert.Nil(t, err)
		assert.Equal(t, http.StatusOK, fileRes.StatusCode,
			"Unable to retrieve the content of %s, wanted %d, got %d: '%s'",
			fileUrl, http.StatusOK, fileRes.StatusCode, fileRes.Status)
		fileRes.Body.Close()
	}
}

func Test_VerifyMediaDocument(t *testing.T) {
	expectedJson := &model.ExpectedMediaGeneric{}
	unmarshalExpectedJson(t, "media-document.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "media", expectedJson.Type)
	assert.Equal(t, "document", expectedJson.Bundle)

	// There are two media with name that were migrated by testcafe
	name := "Fuji Acros Datasheet"

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: "media",
		DrupalBundle: "document",
		Filter:       "name",
		Value:        name,
	}

	res := model.JsonApiDocumentMedia{}
	u.Get(&res)

	// use the first media
	document := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Size, document.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, document.JsonApiAttributes.MimeType)
	assert.Equal(t, expectedJson.OriginalName, document.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Name, document.JsonApiAttributes.Name)
	assert.NotEqual(t, expectedJson.RestrictedAccess, document.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, document.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify
	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(document.JsonApiRelationships.AccessTerms.Data))
	for i := range document.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		document.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(document.JsonApiRelationships.MediaUse.Data))
	for i := range document.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		document.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	document.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)
}

func Test_VerifyMediaImage(t *testing.T) {
	expectedJson := &model.ExpectedMediaImage{}
	unmarshalExpectedJson(t, "media-image.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "media", expectedJson.Type)
	assert.Equal(t, "image", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: "media",
		DrupalBundle: "image",
		Filter:       "name",
		Value:        "Looking For Fossils",
	}

	res := model.JsonApiImageMedia{}
	u.GetSingle(&res)

	// use the first media
	image := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Size, image.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, image.JsonApiAttributes.MimeType)
	assert.Equal(t, expectedJson.OriginalName, image.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Name, image.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Height, image.JsonApiAttributes.Height)
	assert.Equal(t, expectedJson.Width, image.JsonApiAttributes.Width)
	assert.NotEqual(t, expectedJson.RestrictedAccess, image.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, image.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(image.JsonApiRelationships.AccessTerms.Data))
	for i := range image.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		image.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, expectedJson.AltText, image.JsonApiRelationships.File.Data.Meta["alt"])

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(image.JsonApiRelationships.MediaUse.Data))
	for i := range image.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		image.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	image.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	u = &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: "media",
		DrupalBundle: "image",
		Filter:       "name",
		Value:        "Tiff Image",
	}

	res2 := model.JsonApiImageMedia{}
	u.GetSingle(&res2)

	image2 := res2.JsonApiData[0]

	assert.Equal(t, expectedJson.RestrictedAccess, image2.JsonApiAttributes.RestrictedAccess)

	file := model.JsonApiFile{}
	file2 := model.JsonApiFile{}
	res.JsonApiData[0].JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	res2.JsonApiData[0].JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file2, drupalAdmin, drupalPass)

	// check that the first file binary can be accessed where its media is restricted access == false
	// TODO obtain from env
	baseUri := "https://islandora-idc.traefik.me"
	fileUrl := fmt.Sprintf("%s%s", baseUri, file.JsonApiData[0].JsonApiAttributes.Uri.Url)
	fileRes, err := http.Get(fileUrl)

	assert.Nil(t, err)
	assert.Equal(t, "200 OK", fileRes.Status)

	// check that the second file binary cannot be accessed where its media is restricted access == true
	fileUrl = fmt.Sprintf("%s%s", baseUri, file2.JsonApiData[0].JsonApiAttributes.Uri.Url)
	fileRes, err = http.Get(fileUrl)

	assert.Nil(t, err)
	assert.Equal(t, "403 Forbidden", fileRes.Status)
}

func Test_VerifyMediaExtractedText(t *testing.T) {
	expectedJson := &model.ExpectedMediaExtractedText{}
	expectedType := "media"
	expectedBundle := "extracted_text"
	unmarshalExpectedJson(t, "media-extracted_text.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiExtractedTextMedia{}
	u.GetSingle(&res)
	ext := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, ext.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.MimeType, ext.JsonApiAttributes.MimeType)
	assert.EqualValues(t, expectedJson.ExtractedText, ext.JsonApiAttributes.EditedText)
	assert.Equal(t, expectedJson.RestrictedAccess, ext.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, ext.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(ext.JsonApiRelationships.AccessTerms.Data))
	for i := range ext.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		ext.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(ext.JsonApiRelationships.MediaUse.Data))
	for i := range ext.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		ext.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	ext.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	file := model.JsonApiFile{}
	ext.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, expectedJson.OriginalName, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
	assert.Equal(t, expectedJson.OriginalName, file.JsonApiData[0].JsonApiAttributes.Filename)
}

func Test_VerifyMediaFile(t *testing.T) {
	expectedJson := &model.ExpectedMediaGeneric{}
	expectedType := "media"
	expectedBundle := "file"
	unmarshalExpectedJson(t, "media-file.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiGenericFileMedia{}
	u.GetSingle(&res)
	genericFile := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, genericFile.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.MimeType, genericFile.JsonApiAttributes.MimeType)
	assert.EqualValues(t, expectedJson.OriginalName, genericFile.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Size, genericFile.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.RestrictedAccess, genericFile.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, genericFile.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(genericFile.JsonApiRelationships.AccessTerms.Data))
	for i := range genericFile.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		genericFile.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(genericFile.JsonApiRelationships.MediaUse.Data))
	for i := range genericFile.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		genericFile.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.MediaUse, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	genericFile.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	file := model.JsonApiFile{}
	genericFile.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, expectedJson.OriginalName, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
	assert.Equal(t, expectedJson.OriginalName, file.JsonApiData[0].JsonApiAttributes.Filename)
}

func Test_VerifyMediaAudio(t *testing.T) {
	expectedJson := &model.ExpectedMediaGeneric{}
	expectedType := "media"
	expectedBundle := "audio"
	unmarshalExpectedJson(t, "media-audio.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiAudioMedia{}
	u.GetSingle(&res)
	audio := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, audio.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.MimeType, audio.JsonApiAttributes.MimeType)
	assert.EqualValues(t, expectedJson.OriginalName, audio.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Size, audio.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.RestrictedAccess, audio.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, audio.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(audio.JsonApiRelationships.AccessTerms.Data))
	for i := range audio.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		audio.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(audio.JsonApiRelationships.MediaUse.Data))
	for i := range audio.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		audio.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	audio.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	file := model.JsonApiFile{}
	audio.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, expectedJson.OriginalName, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
	assert.Equal(t, expectedJson.OriginalName, file.JsonApiData[0].JsonApiAttributes.Filename)
}

func Test_VerifyMediaVideo(t *testing.T) {
	expectedJson := &model.ExpectedMediaGeneric{}
	expectedType := "media"
	expectedBundle := "video"
	unmarshalExpectedJson(t, "media-video.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiVideoMedia{}
	u.GetSingle(&res)
	video := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, video.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.MimeType, video.JsonApiAttributes.MimeType)
	assert.EqualValues(t, expectedJson.OriginalName, video.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Size, video.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.RestrictedAccess, video.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, video.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(video.JsonApiRelationships.AccessTerms.Data))
	for i := range video.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		video.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(video.JsonApiRelationships.MediaUse.Data))
	for i := range video.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		video.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	video.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	file := model.JsonApiFile{}
	video.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, expectedJson.OriginalName, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
	assert.Equal(t, expectedJson.OriginalName, file.JsonApiData[0].JsonApiAttributes.Filename)
}

func Test_VerifyMediaRemoteVideo(t *testing.T) {
	expectedJson := &model.ExpectedMediaRemoteVideo{}
	expectedType := "media"
	expectedBundle := "remote_video"
	unmarshalExpectedJson(t, "media-remote_video.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiRemoteVideoMedia{}
	u.GetSingle(&res)
	video := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, video.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.EmbedUrl, video.JsonApiAttributes.EmbedUrl)
	assert.Equal(t, expectedJson.RestrictedAccess, video.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, video.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	// TODO: media_of not supported for remote_video?
	//mediaOf := JsonApiIslandoraObj{}
	//video.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	//assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)
}

//---------- Check multiple ingests of media files ------
// These next set of tests test what happens when you run a media
// ingest a few times. They end result should be the same, overall
//
func Test_VerifyMediaDocumentMultipleIngests(t *testing.T) {
	expectedJson := &model.ExpectedMediaGeneric{}
	unmarshalExpectedJson(t, "media-document-multi.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "media", expectedJson.Type)
	assert.Equal(t, "document", expectedJson.Bundle)

	// There are two media with name that were migrated by testcafe
	name := "Fuji Acros Datasheet Multi"

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: "media",
		DrupalBundle: "document",
		Filter:       "name",
		Value:        name,
	}

	res := model.JsonApiDocumentMedia{}
	u.Get(&res)

	// use the first media
	document := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Size, document.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, document.JsonApiAttributes.MimeType)
	assert.Equal(t, expectedJson.OriginalName, document.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Name, document.JsonApiAttributes.Name)
	assert.NotEqual(t, expectedJson.RestrictedAccess, document.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, document.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify
	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(document.JsonApiRelationships.AccessTerms.Data))
	for i := range document.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		document.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(document.JsonApiRelationships.MediaUse.Data))
	for i := range document.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		document.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	document.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	index := strings.Index(expectedJson.OriginalName, ".")
	expectedFilename := expectedJson.OriginalName[:index] + "-multi_0" + expectedJson.OriginalName[index:]

    file := model.JsonApiFile{}
	document.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, 
		expectedFilename, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
}

func Test_VerifyMediaImageMultipleIngests(t *testing.T) {
	expectedJson := &model.ExpectedMediaImage{}
	unmarshalExpectedJson(t, "media-image-multi.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, "media", expectedJson.Type)
	assert.Equal(t, "image", expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: "media",
		DrupalBundle: "image",
		Filter:       "name",
		Value:        "Looking For Fossils Multi",
	}

	res := model.JsonApiImageMedia{}
	u.GetSingle(&res)

	// use the first media
	image := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Size, image.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, image.JsonApiAttributes.MimeType)
	assert.Equal(t, expectedJson.OriginalName, image.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Name, image.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.Height, image.JsonApiAttributes.Height)
	assert.Equal(t, expectedJson.Width, image.JsonApiAttributes.Width)
	assert.NotEqual(t, expectedJson.RestrictedAccess, image.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, image.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(image.JsonApiRelationships.AccessTerms.Data))
	for i := range image.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		image.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, expectedJson.AltText, image.JsonApiRelationships.File.Data.Meta["alt"])

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(image.JsonApiRelationships.MediaUse.Data))
	for i := range image.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		image.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	image.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	u = &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: "media",
		DrupalBundle: "image",
		Filter:       "name",
		Value:        "Tiff Image Multi",
	}

	index := strings.Index(expectedJson.OriginalName, ".")
	expectedFilename := expectedJson.OriginalName[:index] + "-multi_0" + expectedJson.OriginalName[index:]

    file := model.JsonApiFile{}
	image.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, 
		expectedFilename, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)

	res2 := model.JsonApiImageMedia{}
	u.GetSingle(&res2)

	image2 := res2.JsonApiData[0]

	assert.Equal(t, expectedJson.RestrictedAccess, image2.JsonApiAttributes.RestrictedAccess)

	file2 := model.JsonApiFile{}
	res2.JsonApiData[0].JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file2, drupalAdmin, drupalPass)

	// check that the first file binary can be accessed where its media is restricted access == false
	// TODO obtain from env
	baseUri := "https://islandora-idc.traefik.me"
	fileUrl := fmt.Sprintf("%s%s", baseUri, file.JsonApiData[0].JsonApiAttributes.Uri.Url)
	fileRes, err := http.Get(fileUrl)

	assert.Nil(t, err)
	assert.Equal(t, "200 OK", fileRes.Status)

    // check that the second file binary cannot be accessed where its media is restricted access == true
    fileUrl = fmt.Sprintf("%s%s", baseUri, file2.JsonApiData[0].JsonApiAttributes.Uri.Url)
    fileRes, err = http.Get(fileUrl)
	assert.Nil(t, err)
	assert.Equal(t, "403 Forbidden", fileRes.Status)
}

func Test_VerifyMediaExtractedTextMultipleIngests(t *testing.T) {
	expectedJson := &model.ExpectedMediaExtractedText{}
	expectedType := "media"
	expectedBundle := "extracted_text"
	unmarshalExpectedJson(t, "media-extracted_text-multi.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiExtractedTextMedia{}
	u.GetSingle(&res)
	ext := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, ext.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.MimeType, ext.JsonApiAttributes.MimeType)
	assert.EqualValues(t, expectedJson.ExtractedText, ext.JsonApiAttributes.EditedText)
	assert.Equal(t, expectedJson.RestrictedAccess, ext.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, ext.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(ext.JsonApiRelationships.AccessTerms.Data))
	for i := range ext.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		ext.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(ext.JsonApiRelationships.MediaUse.Data))
	for i := range ext.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		ext.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	ext.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	index := strings.Index(expectedJson.OriginalName, ".")
	expectedFilename := expectedJson.OriginalName[:index] + "-multi_0" + expectedJson.OriginalName[index:]

    file := model.JsonApiFile{}
	ext.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, 
		expectedFilename, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
}

func Test_VerifyMediaFileMultipleIngests(t *testing.T) {
	expectedJson := &model.ExpectedMediaGeneric{}
	expectedType := "media"
	expectedBundle := "file"
	unmarshalExpectedJson(t, "media-file-multi.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiGenericFileMedia{}
	u.GetSingle(&res)
	genericFile := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, genericFile.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.MimeType, genericFile.JsonApiAttributes.MimeType)
	assert.EqualValues(t, expectedJson.OriginalName, genericFile.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Size, genericFile.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.RestrictedAccess, genericFile.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, genericFile.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(genericFile.JsonApiRelationships.AccessTerms.Data))
	for i := range genericFile.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		genericFile.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(genericFile.JsonApiRelationships.MediaUse.Data))
	for i := range genericFile.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		genericFile.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.MediaUse, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	genericFile.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	index := strings.Index(expectedJson.OriginalName, ".")
	expectedFilename := expectedJson.OriginalName[:index] + "-multi_0" + expectedJson.OriginalName[index:]

    file := model.JsonApiFile{}
	genericFile.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, 
		expectedFilename, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
}

func Test_VerifyMediaAudioMultipleIngests(t *testing.T) {
	expectedJson := &model.ExpectedMediaGeneric{}
	expectedType := "media"
	expectedBundle := "audio"
	unmarshalExpectedJson(t, "media-audio-multi.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiAudioMedia{}
	u.GetSingle(&res)
	audio := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, audio.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.MimeType, audio.JsonApiAttributes.MimeType)
	assert.EqualValues(t, expectedJson.OriginalName, audio.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Size, audio.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.RestrictedAccess, audio.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, audio.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(audio.JsonApiRelationships.AccessTerms.Data))
	for i := range audio.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		audio.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(audio.JsonApiRelationships.MediaUse.Data))
	for i := range audio.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		audio.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	audio.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	index := strings.Index(expectedJson.OriginalName, ".")
	expectedFilename := expectedJson.OriginalName[:index] + "-multi_0" + expectedJson.OriginalName[index:]

    file := model.JsonApiFile{}
	audio.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, 
		expectedFilename, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
}

func Test_VerifyMediaVideoMultipleIngests(t *testing.T) {
	expectedJson := &model.ExpectedMediaGeneric{}
	expectedType := "media"
	expectedBundle := "video"
	unmarshalExpectedJson(t, "media-video-multi.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiVideoMedia{}
	u.GetSingle(&res)
	video := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, video.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.MimeType, video.JsonApiAttributes.MimeType)
	assert.EqualValues(t, expectedJson.OriginalName, video.JsonApiAttributes.OriginalName)
	assert.Equal(t, expectedJson.Size, video.JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.RestrictedAccess, video.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, video.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	assert.Equal(t, 2, len(expectedJson.AccessTerms))
	assert.Equal(t, len(expectedJson.AccessTerms), len(video.JsonApiRelationships.AccessTerms.Data))
	for i := range video.JsonApiRelationships.AccessTerms.Data {
		use := model.JsonApiIslandoraAccessTerms{}
		video.JsonApiRelationships.AccessTerms.Data[i].Resolve(t, &use)
		assert.Contains(t, expectedJson.AccessTerms, use.JsonApiData[0].JsonApiAttributes.Name)
	}

	assert.Equal(t, 2, len(expectedJson.MediaUse))
	assert.Equal(t, len(expectedJson.MediaUse), len(video.JsonApiRelationships.MediaUse.Data))
	for i := range video.JsonApiRelationships.MediaUse.Data {
		use := model.JsonApiMediaUse{}
		video.JsonApiRelationships.MediaUse.Data[i].Resolve(t, &use)
		assert.Equal(t, expectedJson.MediaUse[i], use.JsonApiData[0].JsonApiAttributes.Name)
	}

	mediaOf := model.JsonApiIslandoraObj{}
	video.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)

	index := strings.Index(expectedJson.OriginalName, ".")
	expectedFilename := expectedJson.OriginalName[:index] + "-multi_0" + expectedJson.OriginalName[index:]

    file := model.JsonApiFile{}
	video.JsonApiRelationships.File.Data.ResolveWithBasicAuth(t, &file, drupalAdmin, drupalPass)
	verifyExpectedUri(t, file.JsonApiData[0].JsonApiAttributes.Uri.Url, file.JsonApiData[0].JsonApiAttributes.Uri.Value, 
		expectedFilename, file.JsonApiData[0].JsonApiAttributes.CreatedDate)
	assert.Equal(t, expectedJson.Size, file.JsonApiData[0].JsonApiAttributes.FileSize)
	assert.Equal(t, expectedJson.MimeType, file.JsonApiData[0].JsonApiAttributes.MimeType)
}

func Test_VerifyMediaRemoteVideoMultipleIngests(t *testing.T) {
	expectedJson := &model.ExpectedMediaRemoteVideo{}
	expectedType := "media"
	expectedBundle := "remote_video"
	unmarshalExpectedJson(t, "media-remote_video-multi.json", &expectedJson)

	// sanity check the expected json
	assert.Equal(t, expectedType, expectedJson.Type)
	assert.Equal(t, expectedBundle, expectedJson.Bundle)

	u := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      DrupalBaseurl,
		DrupalEntity: expectedType,
		DrupalBundle: expectedBundle,
		Filter:       "name",
		Value:        expectedJson.Name,
	}

	res := model.JsonApiRemoteVideoMedia{}
	u.GetSingle(&res)
	video := res.JsonApiData[0]

	// Verify attributes

	assert.Equal(t, expectedJson.Name, video.JsonApiAttributes.Name)
	assert.Equal(t, expectedJson.EmbedUrl, video.JsonApiAttributes.EmbedUrl)
	assert.Equal(t, expectedJson.RestrictedAccess, video.JsonApiAttributes.RestrictedAccess)
	assert.Equal(t, expectedJson.UniqueId, video.JsonApiAttributes.UniqueId)

	// Resolve relationships and verify

	// TODO: media_of not supported for remote_video?
	//mediaOf := JsonApiIslandoraObj{}
	//video.JsonApiRelationships.MediaOf.Data.Resolve(t, &mediaOf)
	//assert.Equal(t, expectedJson.MediaOf, mediaOf.JsonApiData[0].JsonApiAttributes.Title)
}
//
// -- done checking media ingests performed more than once ------
//

// Locates the requested JSON file under the test directory, and unmarshals it into the interface supplied by `value`.
func unmarshalExpectedJson(t *testing.T, fileName string, value interface{}) {
	// TODO: use go:embed
	path := fs.FindExpectedJson(t, fileName)
	expectedFile, err := os.Open(path)
	assert.Nil(t, err, "Error opening file %s: %s", expectedFile, err)
	defer func() { expectedFile.Close() }()
	err = json.NewDecoder(expectedFile).Decode(value)
	assert.Nil(t, err, "Error decoding the content of file %s as JSON: %s", expectedFile, err)
}

// generates the expected URL and Value for media files from a Go template, and compares them to the provided
// actual values
func verifyExpectedUri(t *testing.T, actualUrl, actualValue, mediaFilename, creationDate string) {
	// Used to hold the executed template value
	tmplValue := &strings.Builder{}

	tmplInput.File = mediaFilename
	if createTime, err := time.Parse(model.TsLayout, creationDate); err != nil {
		require.Nil(t, err, "error parsing creation date '%s' using layout '%s': %v", creationDate, model.TsLayout, err)
	} else {
		tmplInput.Date = createTime.Format("2006-01-02")
	}

	err := urlTmpl.Execute(tmplValue, tmplInput)
	require.Nil(t, err, "error executing template: %v", err)
	assert.Equal(t, tmplValue.String(), actualUrl)

	tmplValue.Reset()

	err = valueTmpl.Execute(tmplValue, tmplInput)
	require.Nil(t, err, "error executing template: %v", err)
	assert.Equal(t, tmplValue.String(), actualValue)
}
