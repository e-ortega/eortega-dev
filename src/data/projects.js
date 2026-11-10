// Static data for now — once the backend (ASP.NET Core) exists,
// this is replaced by a call to GET /api/projects.
export const projects = [
  {
    id: "canasta-cr-app",
    name: "CanastaCRApp",
    status: "live",
    statusLabel: "en producción",
    description:
      "Aplicación de e-commerce para canastas de productos locales: catálogo, carrito y procesamiento de pedidos en uso real.",
    stack: "React · ASP.NET Core · SQL Server",
    link: "#",
  },
  {
    id: "telemetry-pipeline",
    name: "Pipeline de Telemetría",
    status: "building",
    statusLabel: "en construcción",
    description:
      "Pipeline de ingesta y monitoreo de métricas de calidad de llamada: API, worker con resiliencia, almacenamiento optimizado y dashboards sobre Log Analytics.",
    stack: "ASP.NET Core · EF Core · Polly · KQL",
    link: null,
  },
];
