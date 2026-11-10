import styles from "./Header.module.css";

export default function Header() {
  return (
    <header className={styles.site}>
      <div className={`wrap ${styles.row}`}>
        <a className={`mono ${styles.wordmark}`} href="#">
          eortega.dev
        </a>
        <nav className={styles.links}>
          <a href="#projects">Proyectos</a>
          <a href="#about">Sobre mí</a>
          <a href="#contact">Contacto</a>
        </nav>
      </div>
    </header>
  );
}
