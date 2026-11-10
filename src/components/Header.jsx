import styles from "./Header.module.css";

export default function Header() {
  return (
    <header className={styles.site}>
      <div className={`wrap ${styles.row}`}>
        <a className={`mono ${styles.wordmark}`} href="#">
          eortega.dev
        </a>
        <nav className={styles.links}>
          <a href="#proyectos">Proyectos</a>
          <a href="#sobre-mi">Sobre mí</a>
          <a href="#contacto">Contacto</a>
        </nav>
      </div>
    </header>
  );
}
