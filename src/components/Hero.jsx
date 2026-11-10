import { useState } from "react";
import styles from "./Hero.module.css";

export default function Hero({ available = true }) {
  const [isAvailable] = useState(available);

  return (
    <section className={styles.hero}>
      <div className="wrap">
        <p className={`mono ${styles.sig}`}>
          esteban_ortega --role backend/devops --base costa_rica
        </p>
        <h1 className={styles.title}>
          Construyo sistemas backend y la infraestructura que los mantiene en
          pie.
        </h1>
        <p className={styles.lead}>
          Ingeniero de software enfocado en APIs, pipelines de datos y
          observabilidad. Diseño y opero la plataforma, no solo el código que
          corre sobre ella.
        </p>
        <div className={styles.statusRow}>
          <span
            className={styles.dot}
            style={{
              background: isAvailable ? "var(--status-ok)" : "var(--status-build)",
            }}
          />
          <span className={styles.statusLabel}>
            {isAvailable ? "Disponible para nuevos proyectos" : "No disponible por ahora"}
          </span>
        </div>
        <p className={`mono ${styles.location}`}>Costa Rica · UTC-6</p>
      </div>
    </section>
  );
}
