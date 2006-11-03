/*
 *  CommonUtils.c
 *  Perian
 *
 *  Created by David Conrad on 10/13/06.
 *  Copyright 2006 Perian Project. All rights reserved.
 *
 */

#include "CommonUtils.h"


typedef struct LanguageTriplet {
	char twoChar[3];
	char threeChar[4];	// (ISO 639-2 3 char code)
	short qtLang;
} LanguageTriplet;

// don't think there's a function already to do ISO 639-1/2 -> language code 
// that SetMediaLanguage() accepts
static const LanguageTriplet ISO_QTLanguages[] = {
	{ "",   "und", langUnspecified },
	{ "af", "afr", langAfrikaans },
	{ "sq", "alb", langAlbanian },
	{ "sq", "sqi", langAlbanian },
	{ "am", "amh", langAmharic },
	{ "ar", "ara", langArabic },
	{ "hy", "arm", langArmenian },
	{ "hy", "hye", langArmenian },
	{ "as", "asm", langAssamese }, 
	{ "ay", "aym", langAymara },
	{ "az", "aze", langAzerbaijani },
	{ "eu", "baq", langBasque },
	{ "eu", "eus", langBasque },
	{ "bn", "ben", langBengali },
	{ "br", "bre", langBreton },
	{ "bg", "bul", langBulgarian },
	{ "my", "bur", langBurmese },
	{ "my", "mya", langBurmese },
	{ "ca", "cat", langCatalan },
	{ "zh", "chi", langTradChinese },
	{ "zh", "zho", langTradChinese },
	{ "cs", "cze", langCzech },
	{ "cs", "ces", langCzech },
	{ "da", "dan", langDanish },
	{ "nl", "dut", langDutch },
	{ "nl", "nld", langDutch },
	{ "dz", "dzo", langDzongkha },
	{ "en", "eng", langEnglish },
	{ "eo", "epo", langEsperanto },
	{ "et", "est", langEstonian },
	{ "fo", "fao", langFaroese },
	{ "fi", "fin", langFinnish },
	{ "fr", "fre", langFrench },
	{ "fr", "fra", langFrench },
	{ "ka", "geo", langGeorgian },
	{ "ka", "kat", langGeorgian },
	{ "de", "ger", langGerman },
	{ "de", "deu", langGerman },
	{ "gl", "glg", langGalician },
	{ "gd", "gla", langScottishGaelic },
	{ "ga", "gle", langIrishGaelic },
	{ "gv", "glv", langManxGaelic },
	{ "",   "grc", langGreekAncient },
	{ "el", "gre", langGreek },
	{ "el", "ell", langGreek },
	{ "gn", "grn", langGuarani },
	{ "gu", "guj", langGujarati },
	{ "he", "heb", langHebrew },
	{ "hi", "hin", langHindi },
	{ "",   "hmn", langHungarian },
	{ "is", "ice", langIcelandic },
	{ "is", "isl", langIcelandic },
	{ "id", "ind", langIndonesian },
	{ "it", "ita", langItalian },
	{ "jv", "jav", langJavaneseRom },
	{ "ja", "jpn", langJapanese },
	{ "kl", "kal", langGreenlandic },
	{ "kn", "kan", langKannada },
	{ "ks", "kas", langKashmiri },
	{ "kk", "kaz", langKazakh },
	{ "km", "khm", langKhmer },
	{ "rw", "kin", langKinyarwanda },
	{ "ky", "kir", langKirghiz },
	{ "ko", "kor", langKorean },
	{ "ku", "kur", langKurdish },
	{ "lo", "lao", langLao },
	{ "la", "lat", langLatin },
	{ "lv", "lav", langLatvian },
	{ "lt", "lit", langLithuanian },
	{ "mk", "mac", langMacedonian },
	{ "mk", "mkd", langMacedonian },
	{ "ml", "mal", langMalayalam },
	{ "mr", "mar", langMarathi },
	{ "ms", "may", langMalayRoman },
	{ "ms", "msa", langMalayRoman },
	{ "mg", "mlg", langMalagasy },
	{ "mt", "mlt", langMaltese },
	{ "mo", "mol", langMoldavian },
	{ "mn", "mon", langMongolian },
	{ "ne", "nep", langNepali },
	{ "nb", "nob", langNorwegian },		// Norwegian Bokmal
	{ "no", "nor", langNorwegian },
	{ "nn", "nno", langNynorsk },
	{ "ny", "nya", langNyanja },
	{ "or", "ori", langOriya },
	{ "om", "orm", langOromo },
	{ "pa", "pan", langPunjabi },
	{ "fa", "per", langPersian },
	{ "fa", "fas", langPersian },
	{ "pl", "pol", langPolish },
	{ "pt", "por", langPortuguese },
	{ "qu", "que", langQuechua },
	{ "ro", "rum", langRomanian },
	{ "ro", "ron", langRomanian },
	{ "rn", "run", langRundi },
	{ "ru", "rus", langRussian },
	{ "sa", "san", langSanskrit },
	{ "sr", "scc", langSerbian },
	{ "sr", "srp", langSerbian },
	{ "hr", "scr", langCroatian },
	{ "hr", "hrv", langCroatian },
	{ "si", "sin", langSinhalese },
	{ "",   "sit", langTibetan },		// Sino-Tibetan (Other)
	{ "sk", "slo", langSlovak },
	{ "sk", "slk", langSlovak },
	{ "sl", "slv", langSlovenian },
	{ "se", "sme", langSami },
	{ "",   "smi", langSami },			// Sami languages (Other)
	{ "sd", "snd", langSindhi },
	{ "so", "som", langSomali },
	{ "es", "spa", langSpanish },
	{ "su", "sun", langSundaneseRom },
	{ "sw", "swa", langSwahili },
	{ "sv", "swe", langSwedish },
	{ "ta", "tam", langTamil },
	{ "tt", "tat", langTatar },
	{ "te", "tel", langTelugu },
	{ "tg", "tgk", langTajiki },
	{ "tl", "tgl", langTagalog },
	{ "th", "tha", langThai },
	{ "bo", "tib", langTibetan },
	{ "bo", "bod", langTibetan },
	{ "ti", "tir", langTigrinya },
	{ "",   "tog", langTongan },		// Tonga (Nyasa, Tonga Islands)
	{ "tr", "tur", langTurkish },
	{ "tk", "tuk", langTurkmen },
	{ "ug", "uig", langUighur },
	{ "uk", "ukr", langUkrainian },
	{ "ur", "urd", langUrdu },
	{ "uz", "uzb", langUzbek },
	{ "vi", "vie", langVietnamese },
	{ "cy", "wel", langWelsh },
	{ "cy", "cym", langWelsh },
	{ "yi", "yid", langYiddish }
};

short TwoCharLangCodeToQTLangCode(char *lang)
{
	int i;
	
	if (strlen(lang) != 2)
		return langUnspecified;
	
	for (i = 0; i < sizeof(ISO_QTLanguages) / sizeof(LanguageTriplet); i++) {
		if (strcasecmp(lang, ISO_QTLanguages[i].twoChar) == 0)
			return ISO_QTLanguages[i].qtLang;
	}
}

short ThreeCharLangCodeToQTLangCode(char *lang)
{
	int i;
	
	if (strlen(lang) != 3)
		return langUnspecified;
	
	for (i = 0; i < sizeof(ISO_QTLanguages) / sizeof(LanguageTriplet); i++) {
		if (strcasecmp(lang, ISO_QTLanguages[i].threeChar) == 0)
			return ISO_QTLanguages[i].qtLang;
	}
}

/* write the int32_t data to target & then return a pointer which points after that data */
uint8_t *write_int32(uint8_t *target, int32_t data)
{
	return write_data(target, (uint8_t*)&data, sizeof(data));
} /* write_int32() */

/* write the int16_t data to target & then return a pointer which points after that data */
uint8_t *write_int16(uint8_t *target, int16_t data)
{
	return write_data(target, (uint8_t*)&data, sizeof(data));
} /* write_int16() */

/* write the data to the target adress & then return a pointer which points after the written data */
uint8_t *write_data(uint8_t *target, uint8_t* data, int32_t data_size)
{
	if(data_size > 0)
		memcpy(target, data, data_size);
	return (target + data_size);
} /* write_data() */
