import { projects } from "../data/projects.js";
import styles from "./Projects.module.css";

export default function Projects() {
  return (
    <section id="proyectos">
      <div className="wrap">
        <h2 className="section-title mono">// proyectos</h2>
        <div className={styles.grid}>
          {projects.map((p) => (
            <article key={p.id} className={styles.card}>
              <div className={styles.cardTop}>
                <h3>{p.name}</h3>
                <span className={styles.pill}>
                  <span
                    className={styles.pillDot}
                    style={{
                      background:
                        p.status === "live"
                          ? "var(--status-ok)"
                          : "var(--status-build)",
                    }}
                  />
                  {p.statusLabel}
                </span>
              </div>
              <p>{p.description}</p>
              <p className={`mono ${styles.stack}`}>{p.stack}</p>
              {p.link && (
                <a className={styles.link} href={p.link} rel="noopener noreferrer">
                  Ver proyecto →
                </a>
              )}
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
