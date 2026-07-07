package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// apiError is the standard error envelope returned by all endpoints.
type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// respondError writes a JSON ApiError response.
func respondError(c *gin.Context, status int, code, message string) {
	c.JSON(status, apiError{Code: code, Message: message})
}

// respondOK wraps data in a { "data": ... } envelope and writes 200.
func respondOK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// respondCreated wraps data in a { "data": ... } envelope and writes 201.
func respondCreated(c *gin.Context, data any) {
	c.JSON(http.StatusCreated, gin.H{"data": data})
}

// respondNoContent writes an empty 204 response.
func respondNoContent(c *gin.Context) {
	c.Status(http.StatusNoContent)
}

// Standard error shortcuts ─────────────────────────────────────────────────

func errBadRequest(c *gin.Context, message string) {
	respondError(c, http.StatusBadRequest, "BAD_REQUEST", message)
}

func errNotFound(c *gin.Context) {
	respondError(c, http.StatusNotFound, "NOT_FOUND", "Requested resource was not found.")
}

func errInternal(c *gin.Context) {
	respondError(c, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", "Something went wrong.")
}
