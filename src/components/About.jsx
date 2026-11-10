import styles from "./About.module.css";

export default function About() {
  return (
    <section id="sobre-mi">
      <div className="wrap">
        <h2 className="section-title mono">// sobre mí</h2>
        <div className={styles.copy}>
          <p>
            Empecé en validación de hardware en Intel, trabajando cerca del
            silicio y de los procesos de prueba. Desde ahí me moví a
            desarrollo backend y, más recientemente, a ingeniería de
            plataforma y DevOps: monitoreo, pipelines de CI/CD y
            confiabilidad de sistemas.
          </p>
          <p>
            Además del trabajo diario, enseño desarrollo web — explicar cómo
            funcionan las cosas es, para mí, la mejor forma de seguir
            entendiéndolas a fondo.
          </p>
        </div>
      </div>
    </section>
  );
}
