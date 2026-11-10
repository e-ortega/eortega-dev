import { useState } from "react";
import styles from "./Contact.module.css";

const EMAIL = "hola@eortega.dev";

export default function Contact() {
  const [copied, setCopied] = useState(false);

  async function handleCopy() {
    try {
      await navigator.clipboard.writeText(EMAIL);
    } catch (e) {
      // noop — igual mostramos el estado "Copiado" para no bloquear al usuario
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  }

  return (
    <section id="contacto">
      <div className="wrap">
        <h2 className="section-title mono">// contacto</h2>
        <p className={styles.lead}>
          ¿Un proyecto, una vacante o solo una pregunta técnica? Escribime
          directamente.
        </p>
        <div className={`mono ${styles.box}`}>
          <span>{EMAIL}</span>
          <button type="button" onClick={handleCopy}>
            {copied ? "Copiado" : "Copiar"}
          </button>
        </div>
      </div>
    </section>
  );
}
