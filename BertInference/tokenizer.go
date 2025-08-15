package BertInference

import (
	"bufio"
	"os"
	"strings"
	"unicode"
)

func LoadVocab(path string) (map[string]int, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	vocab := make(map[string]int)
	scanner := bufio.NewScanner(file)
	index := 0
	for scanner.Scan() {
		token := scanner.Text()
		vocab[token] = index
		index++
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return vocab, nil
}

func encode_word(word string, vocab map[string]int) []string {
	tokens := []string{}

	for len(word) > 0 {
		i := len(word)
		found := false

		for i > 0 {
			sub := word[:i]
			if _, exists := vocab[sub]; exists {
				found = true
				tokens = append(tokens, sub)
				word = word[i:]
				if len(word) > 0 {
					word = "##" + word
				}
				break
			}
			i--
		}
		if !found {
			tokens = append(tokens, "[UNK]")
			break
		}
	}
	return tokens
}

func TokenizeBert(text string, vocab map[string]int) []string {
	tokens := []string{}
	word := ""

	for _, char := range text {
		if unicode.IsLetter(char) || unicode.IsDigit(char) {
			word += string(char)
		} else {
			if word != "" {
				encoded_word := encode_word(strings.ToLower(word), vocab)
				tokens = append(tokens, encoded_word...)
				word = ""
			}
			if !unicode.IsSpace(char) {
				tokens = append(tokens, string(char))
			}
		}
	}

	if word != "" {
		tokens = append(tokens, word)
	}

	return tokens
}

func BertEncode(text string, vocab map[string]int, maxLen int) ([]int64, []int64, []int64) {
	tokens := []string{"[CLS]"}
	tokens = append(tokens, TokenizeBert(text, vocab)...)
	tokens = append(tokens, "[SEP]")

	inputIds := make([]int64, 0, len(tokens))
	for _, token := range tokens {
		id, exists := vocab[token]
		if !exists {
			id = vocab["[UNK]"]
		}
		inputIds = append(inputIds, int64(id))
	}

	attentionMask := make([]int64, len(inputIds))
	for i := range attentionMask {
		attentionMask[i] = 1
	}

	tokenTypeIDs := make([]int64, len(inputIds))

	for len(inputIds) < maxLen {
		inputIds = append(inputIds, 0)
		attentionMask = append(attentionMask, 0)
		tokenTypeIDs = append(tokenTypeIDs, 0)
	}

	// Truncate if too long
	if len(inputIds) > maxLen {
		inputIds = inputIds[:maxLen]
		attentionMask = attentionMask[:maxLen]
		tokenTypeIDs = tokenTypeIDs[:maxLen]
	}

	return inputIds, attentionMask, tokenTypeIDs
}
