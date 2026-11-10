import styles from "./Footer.module.css";

export default function Footer() {
  return (
    <footer className={styles.site}>
      <div className={`wrap ${styles.row}`}>
        <span>© 2026 Esteban Ortega</span>
        <span>Construido con React, ASP.NET Core, Azure y Oracle Cloud</span>
      </div>
    </footer>
  );
}
