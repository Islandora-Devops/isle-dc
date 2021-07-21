package main

import (
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/jhu-idc/idc-golang/drupal/env"
	"github.com/jhu-idc/idc-golang/drupal/jsonapi"
	"github.com/jhu-idc/idc-golang/drupal/model"
	"github.com/stretchr/testify/assert"
	"io/fs"
	"log"
	"math"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

const (
	// Env var name for the base URL to media assets
	assetsBaseUrlEnv = "BASE_ASSETS_URL"
	drupalBaseUrl    = "https://islandora-idc.traefik.me"

	// Env var containing the homarus timeout
	homarusSocketTimeout = "ALPACA_HOMERUS_HTTP_SOCKET_TIMEOUT_MS"

	// default timeout value
	defaultTimeout = time.Duration(30) * time.Second

	expectedCollectionCount             = 1
	expectedRepoObjectCount             = 8
	expectedOriginalDocumentsMediaCount = 1
	expectedOriginalVideoCount          = 2
	expectedOriginalImageCount          = 5
	expectedDerivativeThumbCount        = expectedRepoObjectCount - expectedOriginalDocumentsMediaCount // the PDF doesn't have a thumbnail
	expectedDerivativeFitsCount         = expectedRepoObjectCount - 1                                   // TODO: the first image doesn't have a FITS file
	expectedDerivativeExtractedTxtCount = expectedOriginalDocumentsMediaCount                           // Only the PDF has extracted text
	expectedDerivativeServiceCount      = expectedRepoObjectCount - expectedOriginalDocumentsMediaCount // The PDF doesn't have a service file; TODO: Missing service files for the large and small video
)

var expectedCount = struct {
	// The expected number of collections containing the test objects
	collections int
	// The expected number of repository objects ingested by the testcafe migration
	objects int
	// The expected number of documents media ingested by the testcafe migration
	originalDocuments int
	// The expected number of video media ingested by the testcafe migration
	originalVideos int
	// The expected number of image media ingested by the testcafe migration
	originalImages int
	// The expected number of derivative thumbnails generated after migration
	derivativeThumbnails int
	// The expected number of FITS technical metadata generated after migration
	derivativeFits int
	// The expected number of extracted text media generated after migration
	derivativeExtractedText int
	// The expected number of service files generated after migration
	derivativeService int
}{
	expectedCollectionCount,
	expectedRepoObjectCount,
	expectedOriginalDocumentsMediaCount,
	expectedOriginalVideoCount,
	expectedOriginalImageCount,
	expectedDerivativeThumbCount,
	expectedDerivativeFitsCount,
	expectedDerivativeExtractedTxtCount,
	expectedDerivativeServiceCount,
}

// The embedded filesystem containing JSON representations of expected entities in Drupal
//go:embed expected/*
var expectedJson embed.FS

// All objects and media reside under a single collection, make sure it exists
func Test_Collection(t *testing.T) {
	expected := &model.ExpectedCollection{}
	assert.Nil(t, unmarshal("expected/collection.json", expected))

	req := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      env.BaseUrlOr(drupalBaseUrl),
		DrupalEntity: expected.Type,
		DrupalBundle: expected.Bundle,
		Filter:       "title",
		Value:        expected.Title,
	}

	actual := &model.JsonApiCollection{}
	req.GetSingle(actual)

	assert.Equal(t, expected.Title, actual.JsonApiData[0].JsonApiAttributes.Title)
}

// Insure all 8 repository objects exist
func Test_RepositoryObjects(t *testing.T) {
	// Collect the filenames of the expected repository objects
	filenames := filenamesMatching(t, "io-")

	// Should be 8 expected repository objects
	assert.Len(t, filenames, expectedCount.objects)

	// Verify each expected repository object exists
	for _, filename := range filenames {
		expected := &model.ExpectedRepoObj{}
		assert.Nil(t, unmarshal(filename, expected))

		req := &jsonapi.JsonApiUrl{
			T:            t,
			BaseUrl:      env.BaseUrlOr(drupalBaseUrl),
			DrupalEntity: expected.Type,
			DrupalBundle: expected.Bundle,
			Filter:       "title",
			Value:        expected.Title,
		}

		actual := &model.JsonApiIslandoraObj{}
		req.GetSingle(actual)

		assert.Equal(t, expected.Title, actual.JsonApiData[0].JsonApiAttributes.Title)
	}
}

func Test_Original_Media_Documents(t *testing.T) {
	// Collect the filenames of the expected original document media
	filenames := filenamesMatching(t, "-documents-original")
	assert.Len(t, filenames, expectedCount.originalDocuments)

	// Verify each expected media exists
	for _, filename := range filenames {
		var expectedMedia model.NamedOrTitled
		expectedMedia = &model.ExpectedMediaGeneric{}
		assert.Nil(t, unmarshal(filename, expectedMedia.(*model.ExpectedMediaGeneric)))
		actual := &model.JsonApiDocumentMedia{}

		assertExists(t, expectedMedia, actual, func(expected, actual interface{}) {
			jsonApiData := actual.(*model.JsonApiDocumentMedia).JsonApiData
			assert.Equal(t, 1, len(jsonApiData), "Expected 1 data element, found %d element(s)", len(jsonApiData))

			actualName := jsonApiData[0].JsonApiAttributes.Name
			assert.NotEmpty(t, expectedMedia.NameOrTitle())
			assert.Equal(t, expectedMedia.NameOrTitle(), actualName)
		})
	}
}

func Test_Original_Media_Videos(t *testing.T) {
	// Collect the filenames of the expected original video media
	filenames := filenamesMatching(t, "video-original")
	assert.Len(t, filenames, expectedCount.originalVideos)

	// Verify each expected media exists
	for _, filename := range filenames {
		var expectedMedia model.NamedOrTitled
		expectedMedia = &model.ExpectedMediaGeneric{}
		assert.Nil(t, unmarshal(filename, expectedMedia.(*model.ExpectedMediaGeneric)))
		actual := &model.JsonApiVideoMedia{}

		assertExists(t, expectedMedia, actual, func(expected, actual interface{}) {
			jsonApiData := actual.(*model.JsonApiVideoMedia).JsonApiData
			assert.Equal(t, 1, len(jsonApiData), "Expected 1 data element, found %d element(s)", len(jsonApiData))
			actualName := jsonApiData[0].JsonApiAttributes.Name

			assert.NotEmpty(t, expectedMedia.NameOrTitle())
			assert.Equal(t, expectedMedia.NameOrTitle(), actualName)
		})
	}
}

func Test_Original_Media_Images(t *testing.T) {
	// Collect the filenames of the expected original image media
	filenames := filenamesMatching(t, "-image-original")
	assert.Len(t, filenames, expectedCount.originalImages)

	// Verify each expected media exists
	for _, filename := range filenames {
		var expectedMedia model.NamedOrTitled
		expectedMedia = &model.ExpectedMediaGeneric{}
		assert.Nil(t, unmarshal(filename, expectedMedia.(*model.ExpectedMediaGeneric)))
		actual := &model.JsonApiImageMedia{}

		assertExists(t, expectedMedia, actual, func(expected, actual interface{}) {
			jsonApiData := actual.(*model.JsonApiImageMedia).JsonApiData
			assert.Equal(t, 1, len(jsonApiData), "Expected 1 data element, found %d element(s)", len(jsonApiData))
			actualName := jsonApiData[0].JsonApiAttributes.Name

			assert.NotEmpty(t, expectedMedia.NameOrTitle())
			assert.Equal(t, expectedMedia.NameOrTitle(), actualName)
		})
	}
}

func Test_Derivative_Thumbnail_Media(t *testing.T) {
	// Run derivative tests in parallel to avoid long wait times
	t.Parallel()

	// Collect the filenames of the expected thumbnail media
	// - the PDF (media-documents-original) won't have one
	filenames := filenamesMatching(t, "thumb")
	assert.Len(t, filenames, expectedCount.derivativeThumbnails,
		"Expected %d files but got %d", expectedCount.derivativeThumbnails, len(filenames))

	// Thumbnail files take some time to generate, so we need to wait
	timeout, _ := strconv.Atoi(env.GetEnvOr(homarusSocketTimeout, defaultTimeout.String()))

	// Execute each request for a thumbnail in its own goroutine

	wg := sync.WaitGroup{}
	wg.Add(len(filenames))

	for _, filename := range filenames {
		var expectedMedia model.NamedOrTitled
		expectedMedia = &model.ExpectedMediaGeneric{}
		unmarshalErr := unmarshal(filename, expectedMedia.(*model.ExpectedMediaGeneric))
		assert.Nil(t, unmarshalErr, "error unmarshaling '%s': %s", filename, unmarshalErr)
		actual := &model.JsonApiImageMedia{}

		go func() {
			err := doUntil(func() error {
				var err error
				assertExists(t, expectedMedia, actual, func(expected, actual interface{}) {
					jsonApiData := actual.(*model.JsonApiImageMedia).JsonApiData
					if len(jsonApiData) == 1 {
						assert.NotEmpty(t, expectedMedia.NameOrTitle())
						assert.Equal(t, expectedMedia.NameOrTitle(), jsonApiData[0].JsonApiAttributes.Name)
						err = done
					}
				})

				if len(actual.JsonApiData) > 1 {
					err = errors.New(fmt.Sprintf("too many results retrieving JSONAPI entity %s, bundle %s, %s %s",
						expectedMedia.EntityType(), expectedMedia.EntityBundle(), expectedMedia.Field(), expectedMedia.NameOrTitle()))
				}

				return err
			}, time.Now().Add(time.Duration(timeout)*time.Millisecond), 1000, 2.0)

			assert.Equal(t, done, err, "Failed retrieving '%s': %s", expectedMedia.NameOrTitle(), err)
			wg.Done()
		}()
	}

	wg.Wait()
}

func Test_Derivative_Fits_Media(t *testing.T) {
	// Run derivative tests in parallel to avoid long wait times
	t.Parallel()

	// Collect the filenames of the expected fits media
	// TODO: media-image-fits-01 won't have one
	filenames := filenamesMatching(t, "fits")
	assert.Len(t, filenames, expectedCount.derivativeFits,
		"Expected %d files but got %d", expectedCount.derivativeFits, len(filenames))

	// Execute each request for fits media in its own goroutine

	wg := sync.WaitGroup{}
	wg.Add(len(filenames))

	for _, filename := range filenames {
		var expectedMedia model.NamedOrTitled
		expectedMedia = &model.ExpectedMediaGeneric{}
		unmarshalErr := unmarshal(filename, expectedMedia.(*model.ExpectedMediaGeneric))
		assert.Nil(t, unmarshalErr, "error unmarshaling '%s': %s", filename, unmarshalErr)
		actual := &model.JsonApiFitsMedia{}

		go func() {
			err := doUntil(func() error {
				var err error
				assertExists(t, expectedMedia, actual, func(expected, actual interface{}) {
					jsonApiData := actual.(*model.JsonApiFitsMedia).JsonApiData
					if len(jsonApiData) == 1 {
						assert.NotEmpty(t, expectedMedia.NameOrTitle())
						assert.Equal(t, expectedMedia.NameOrTitle(), jsonApiData[0].JsonApiAttributes.Name)
						err = done
					}
				})

				if len(actual.JsonApiData) > 1 {
					err = errors.New(fmt.Sprintf("too many results retrieving JSONAPI entity %s, bundle %s, %s %s",
						expectedMedia.EntityType(), expectedMedia.EntityBundle(), expectedMedia.Field(), expectedMedia.NameOrTitle()))
				}

				return err
			}, time.Now().Add(defaultTimeout), 1000, 2.0)

			assert.Equal(t, done, err, "Failed retrieving '%s': %s", expectedMedia.NameOrTitle(), err)

			wg.Done()
		}()
	}

	wg.Wait()
}

func Test_Derivative_ExtractedText_Media(t *testing.T) {
	// Run derivative tests in parallel to avoid long wait times
	t.Parallel()

	// Collect the filenames of the expected extracted text media
	filenames := filenamesMatching(t, "extracted")
	assert.Len(t, filenames, expectedCount.derivativeExtractedText,
		"Expected %d files but got %d", expectedCount.derivativeExtractedText, len(filenames))

	wg := sync.WaitGroup{}
	wg.Add(len(filenames))

	for _, filename := range filenames {
		var expectedMedia model.NamedOrTitled
		expectedMedia = &model.ExpectedMediaGeneric{}
		assert.Nil(t, unmarshal(filename, expectedMedia.(*model.ExpectedMediaGeneric)))
		actual := &model.JsonApiGenericFileMedia{}

		go func() {
			err := doUntil(func() error {
				var err error
				assertExists(t, expectedMedia, actual, func(expected, actual interface{}) {
					jsonApiData := actual.(*model.JsonApiGenericFileMedia).JsonApiData
					if len(jsonApiData) == 1 {
						assert.NotEmpty(t, expectedMedia.NameOrTitle())
						assert.Equal(t, expectedMedia.NameOrTitle(), jsonApiData[0].JsonApiAttributes.Name)
						err = done
					}
				})

				if len(actual.JsonApiData) > 1 {
					err = errors.New(fmt.Sprintf("too many results retrieving JSONAPI entity %s, bundle %s, %s %s",
						expectedMedia.EntityType(), expectedMedia.EntityBundle(), expectedMedia.Field(), expectedMedia.NameOrTitle()))
				}

				return err
			}, time.Now().Add(defaultTimeout), 1000, 2.0)

			assert.Equal(t, done, err, "Failed retrieving '%s': %s", expectedMedia.NameOrTitle(), err)

			wg.Done()
		}()
	}

	wg.Wait()
}

func Test_Derivative_Service_Media(t *testing.T) {
	// Run derivative tests in parallel to avoid long wait times
	t.Parallel()

	// Collect the filenames of the expected service media
	filenames := filenamesMatching(t, "svc")
	assert.Len(t, filenames, expectedCount.derivativeService,
		"Expected %d files but got %d", expectedCount.derivativeService, len(filenames))

	// Video files take a while to generate, so we need to wait
	timeout, _ := strconv.Atoi(env.GetEnvOr(homarusSocketTimeout, defaultTimeout.String()))

	// Execute each request for service media in its own goroutine

	wg := sync.WaitGroup{}
	wg.Add(len(filenames))

	for _, filename := range filenames {
		var expectedMedia model.NamedOrTitled
		expectedMedia = &model.ExpectedMediaGeneric{}
		assert.Nil(t, unmarshal(filename, expectedMedia.(*model.ExpectedMediaGeneric)))
		actual := &model.JsonApiGenericFileMedia{}

		go func() {
			err := doUntil(func() error {
				var err error
				assertExists(t, expectedMedia, actual, func(expected, actual interface{}) {
					jsonApiData := actual.(*model.JsonApiGenericFileMedia).JsonApiData
					if len(jsonApiData) == 1 {
						assert.NotEmpty(t, expectedMedia.NameOrTitle())
						assert.Equal(t, expectedMedia.NameOrTitle(), jsonApiData[0].JsonApiAttributes.Name)
						err = done
					}
				})

				if len(actual.JsonApiData) > 1 {
					err = errors.New(fmt.Sprintf("too many results retrieving JSONAPI entity %s, bundle %s, %s %s",
						expectedMedia.EntityType(), expectedMedia.EntityBundle(), expectedMedia.Field(), expectedMedia.NameOrTitle()))
				}

				return err

			}, time.Now().Add(time.Duration(timeout)*time.Millisecond), 5000, 1.5)

			assert.Equal(t, done, err, "Failed retrieving '%s': %s", expectedMedia.NameOrTitle(), err)

			wg.Done()
		}()
	}

	wg.Wait()
}

// Searches the 'expected' directory of the embedded filesystem for file names (not paths) that contain the supplied
// substring.  Answers an array of matching paths (which include the file name).
func filenamesMatching(t *testing.T, substring string) []string {
	filenames := []string{}
	err := fs.WalkDir(expectedJson, "expected", func(path string, d fs.DirEntry, err error) error {
		assert.Nil(t, err)
		if strings.Contains(d.Name(), substring) {
			filenames = append(filenames, path)
		}
		return nil
	})
	assert.Nil(t, err)

	return filenames
}

// Opens the supplied file path and unmarshals the JSON into the supplied interface.  The supplied filepath is assumed
// to be present in the embedded filesystem
func unmarshal(filepath string, value interface{}) (err error) {
	var file fs.File
	if file, err = expectedJson.Open(filepath); err != nil {
		return err
	}

	return json.NewDecoder(file).Decode(value)
}

// Retrieves the expected entity from Drupal and executes the supplied assertion.
//
// The caller provides a populated expected entity, this function will do the legwork of retrieving the actual value and
// executing the assertion.
func assertExists(t *testing.T, expected model.NamedOrTitled, actual interface{}, assertionFn func(expected, actual interface{})) {
	req := &jsonapi.JsonApiUrl{
		T:            t,
		BaseUrl:      env.BaseUrlOr(drupalBaseUrl),
		DrupalEntity: expected.EntityType(),
		DrupalBundle: expected.EntityBundle(),
		Filter:       expected.Field(),
		Value:        expected.NameOrTitle(),
	}

	req.Get(&actual)

	assertionFn(expected, actual)
}

var (
	// return indicating doUntil ends cleanly
	done = errors.New("done")
	// return indicating the deadline for doUntil expired
	expired = errors.New("deadline expired")
)

// Executes the supplied function in a loop, sleeping between each execution.
//
// The loop (and doUntil) terminates when fn returns an error, or when the deadline expires.  Two special errors,
// 'expired' and 'done', may be returned by fn.  Returning 'nil' will have the loop continue.
//
// The sleep time is determined by the initial backoff time and the backoff factor.  The backoff time is multiplied by
// the backoff factor each time fn is executed.
func doUntil(fn func() error, deadline time.Time, initialBackoffMs int, backoffFactor float64) error {
	var backoff = initialBackoffMs
	var last = false
	for time.Now().Before(deadline) || last {
		if err := fn(); err != nil {
			return err
		}

		// this was our last iteration, break out
		if last {
			break
		}

		backoff = int(math.Ceil(float64(backoff) * backoffFactor))

		// if the deadline will be exceeded on the next iteration, only sleep till the deadline and make one more
		// attempt
		if time.Now().Add(time.Duration(backoff) * time.Millisecond).After(deadline) {
			last = true
			time.Sleep(deadline.Sub(time.Now()))
		} else {
			time.Sleep(time.Duration(backoff) * time.Millisecond)
		}
	}

	log.Printf("deadline expired")
	return expired
}
