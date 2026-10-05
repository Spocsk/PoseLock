"use strict";

// Langues du site. La valeur reçue du navigateur n'est jamais utilisée telle
// quelle : tout ce qui n'est pas dans cette liste retombe sur le français.
const LOCALES = ["fr", "en", "es", "de", "pt-BR"];

const CONFIRMATION_PATH = {
  fr: "/confirmation/",
  en: "/en/confirm/",
  es: "/es/confirmar/",
  de: "/de/bestaetigen/",
  "pt-BR": "/pt-br/confirmar/"
};

const MESSAGES = {
  fr: {
    method: "Méthode non autorisée.",
    tooLong: "Requête trop longue.",
    closed: "Les inscriptions ouvriront sur poselock.app.",
    origin: "Origine non autorisée.",
    invalid: "Requête invalide.",
    email: "Saisis une adresse valide et accepte les emails PoseLock.",
    unavailable: "Les inscriptions sont momentanément indisponibles.",
    sendFailed: "L’envoi a échoué. Réessaie plus tard.",
    badLink: "Ce lien est invalide.",
    expired: "Ce lien a expiré. Inscris-toi à nouveau.",
    confirmUnavailable: "La confirmation est momentanément indisponible.",
    confirmFailed: "La confirmation a échoué. Réessaie plus tard.",
    subject: "Confirme ton inscription à PoseLock",
    heading: "Confirme ton adresse.",
    intro: "Tu as demandé à recevoir la sortie et les actualités PoseLock.",
    button: "Confirmer mon inscription",
    footer: "Ce lien expire dans 24 heures. Si tu n’as rien demandé, ignore ce message.",
    text: "Tu as demandé à recevoir la sortie et les actualités PoseLock. Confirme ton adresse dans les 24 heures : {link}\n\nSi tu n’as rien demandé, ignore ce message."
  },
  en: {
    method: "Method not allowed.",
    tooLong: "Request too long.",
    closed: "Sign-ups will open on poselock.app.",
    origin: "Origin not allowed.",
    invalid: "Invalid request.",
    email: "Enter a valid address and accept PoseLock emails.",
    unavailable: "Sign-ups are temporarily unavailable.",
    sendFailed: "Sending failed. Please try again later.",
    badLink: "This link is invalid.",
    expired: "This link has expired. Please sign up again.",
    confirmUnavailable: "Confirmation is temporarily unavailable.",
    confirmFailed: "Confirmation failed. Please try again later.",
    subject: "Confirm your PoseLock sign-up",
    heading: "Confirm your address.",
    intro: "You asked to hear about the PoseLock launch and news.",
    button: "Confirm my sign-up",
    footer: "This link expires in 24 hours. If you didn’t ask for this, ignore this message.",
    text: "You asked to hear about the PoseLock launch and news. Confirm your address within 24 hours: {link}\n\nIf you didn’t ask for this, ignore this message."
  },
  es: {
    method: "Método no permitido.",
    tooLong: "Solicitud demasiado larga.",
    closed: "Las inscripciones se abrirán en poselock.app.",
    origin: "Origen no permitido.",
    invalid: "Solicitud no válida.",
    email: "Escribe una dirección válida y acepta los emails de PoseLock.",
    unavailable: "Las inscripciones no están disponibles por ahora.",
    sendFailed: "No se pudo enviar. Inténtalo más tarde.",
    badLink: "Este enlace no es válido.",
    expired: "Este enlace ha caducado. Vuelve a inscribirte.",
    confirmUnavailable: "La confirmación no está disponible por ahora.",
    confirmFailed: "No se pudo confirmar. Inténtalo más tarde.",
    subject: "Confirma tu inscripción en PoseLock",
    heading: "Confirma tu dirección.",
    intro: "Has pedido recibir el lanzamiento y las novedades de PoseLock.",
    button: "Confirmar mi inscripción",
    footer: "Este enlace caduca en 24 horas. Si no lo has pedido, ignora este mensaje.",
    text: "Has pedido recibir el lanzamiento y las novedades de PoseLock. Confirma tu dirección en las próximas 24 horas: {link}\n\nSi no lo has pedido, ignora este mensaje."
  },
  de: {
    method: "Methode nicht erlaubt.",
    tooLong: "Anfrage zu lang.",
    closed: "Die Anmeldung öffnet auf poselock.app.",
    origin: "Herkunft nicht erlaubt.",
    invalid: "Ungültige Anfrage.",
    email: "Gib eine gültige Adresse ein und stimme den PoseLock-E-Mails zu.",
    unavailable: "Die Anmeldung ist vorübergehend nicht verfügbar.",
    sendFailed: "Senden fehlgeschlagen. Bitte versuch es später erneut.",
    badLink: "Dieser Link ist ungültig.",
    expired: "Dieser Link ist abgelaufen. Bitte melde dich erneut an.",
    confirmUnavailable: "Die Bestätigung ist vorübergehend nicht verfügbar.",
    confirmFailed: "Bestätigung fehlgeschlagen. Bitte versuch es später erneut.",
    subject: "Bestätige deine Anmeldung bei PoseLock",
    heading: "Bestätige deine Adresse.",
    intro: "Du möchtest über den Start und Neuigkeiten von PoseLock informiert werden.",
    button: "Anmeldung bestätigen",
    footer: "Dieser Link läuft in 24 Stunden ab. Wenn du nichts angefordert hast, ignoriere diese Nachricht.",
    text: "Du möchtest über den Start und Neuigkeiten von PoseLock informiert werden. Bestätige deine Adresse innerhalb von 24 Stunden: {link}\n\nWenn du nichts angefordert hast, ignoriere diese Nachricht."
  },
  "pt-BR": {
    method: "Método não permitido.",
    tooLong: "Solicitação longa demais.",
    closed: "As inscrições vão abrir em poselock.app.",
    origin: "Origem não permitida.",
    invalid: "Solicitação inválida.",
    email: "Informe um endereço válido e aceite os emails do PoseLock.",
    unavailable: "As inscrições estão indisponíveis no momento.",
    sendFailed: "O envio falhou. Tente de novo mais tarde.",
    badLink: "Este link é inválido.",
    expired: "Este link expirou. Inscreva-se de novo.",
    confirmUnavailable: "A confirmação está indisponível no momento.",
    confirmFailed: "A confirmação falhou. Tente de novo mais tarde.",
    subject: "Confirme sua inscrição no PoseLock",
    heading: "Confirme seu endereço.",
    intro: "Você pediu para receber o lançamento e as novidades do PoseLock.",
    button: "Confirmar minha inscrição",
    footer: "Este link expira em 24 horas. Se você não pediu nada, ignore esta mensagem.",
    text: "Você pediu para receber o lançamento e as novidades do PoseLock. Confirme seu endereço em até 24 horas: {link}\n\nSe você não pediu nada, ignore esta mensagem."
  }
};

function locale(value) {
  return LOCALES.includes(value) ? value : "fr";
}

function messages(value) {
  return MESSAGES[locale(value)];
}

function confirmationPath(value) {
  return CONFIRMATION_PATH[locale(value)];
}

module.exports = { LOCALES, locale, messages, confirmationPath };
